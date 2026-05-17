import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import express, {Request, Response} from 'express';

admin.initializeApp();

const db = admin.firestore();
const app = express();
app.use(express.json());

// ── helpers ───────────────────────────────────────────────────────────────────

async function sendPushForAlert(params: {
  title: string;
  body: string;
  type: 'expiry' | 'low_stock';
  severity: string;
  alertId: string;
}) {
  const tokensSnap = await db.collection('device_tokens').get();
  const tokens = tokensSnap.docs
    .map((d) => (d.data().token as string | undefined)?.trim())
    .filter((t): t is string => !!t)
    .slice(0, 500);

  if (tokens.length === 0) return;

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {title: params.title, body: params.body},
    data: {
      route: 'alerts',
      type: params.type,
      severity: params.severity,
      alertId: params.alertId,
    },
  });
}

/**
 * Converte um campo no formato REST do Firestore para valor JS nativo.
 * Eventarc envia o documento neste formato (ex: { "stringValue": "foo" }).
 */
function firestoreFieldToValue(field: Record<string, unknown>): unknown {
  if ('stringValue' in field) return field.stringValue;
  if ('integerValue' in field) return Number(field.integerValue);
  if ('doubleValue' in field) return field.doubleValue;
  if ('booleanValue' in field) return field.booleanValue;
  if ('nullValue' in field) return null;
  if ('timestampValue' in field) return field.timestampValue;
  if ('arrayValue' in field) {
    const arr = (field.arrayValue as {values?: Record<string, unknown>[]}).values ?? [];
    return arr.map(firestoreFieldToValue);
  }
  if ('mapValue' in field) {
    const mapFields =
      (field.mapValue as {fields?: Record<string, Record<string, unknown>>}).fields ?? {};
    return firestoreDocToObject(mapFields);
  }
  return null;
}

function firestoreDocToObject(
  fields: Record<string, Record<string, unknown>>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(fields)) {
    result[key] = firestoreFieldToValue(val);
  }
  return result;
}

/** Extrai collectionId e docId a partir do resource name do Firestore.
 *  Formato: projects/{proj}/databases/{db}/documents/{collection}/{docId}
 */
function parseDocumentName(name: string): {collectionId: string; docId: string} {
  const segment = name.split('/documents/')[1] ?? '';
  const parts = segment.split('/');
  return {collectionId: parts[0] ?? '', docId: parts[1] ?? ''};
}

// ── health check ──────────────────────────────────────────────────────────────

app.get('/', (_req, res) => res.send('OK'));

// ── POST /generate-expiry-alerts  (chamado pelo Cloud Scheduler) ──────────────

app.post('/generate-expiry-alerts', async (_req: Request, res: Response) => {
  try {
    const settingsDoc = await db.collection('settings').doc('alerts').get();
    const criticalDays = (settingsDoc.data()?.criticalDays as number | undefined) ?? 7;
    const warningDays = (settingsDoc.data()?.warningDays as number | undefined) ?? 30;

    const today = new Date();
    const warningLimit = new Date(today);
    warningLimit.setDate(today.getDate() + warningDays);

    const batchesSnap = await db
      .collection('batches')
      .where('status', '==', 'disponivel')
      .where('noExpiry', '==', false)
      .where('quantity', '>', 0)
      .get();

    const writes: Array<Promise<FirebaseFirestore.WriteResult>> = [];

    for (const doc of batchesSnap.docs) {
      const data = doc.data();
      const expiryRaw = data.expiryDate as string | undefined;
      if (!expiryRaw) continue;

      const expiry = new Date(expiryRaw);
      if (Number.isNaN(expiry.getTime()) || expiry > warningLimit) continue;

      const daysToExpiry = Math.ceil((expiry.getTime() - today.getTime()) / 86400000);
      const severity = daysToExpiry <= criticalDays ? 'critical' : 'warning';
      const alertId = `${doc.id}_${severity}`;

      writes.push(
        db.collection('alerts').doc(alertId).set(
          {
            type: 'expiry',
            severity,
            batchId: doc.id,
            productId: data.productId,
            productName: data.productName,
            daysToExpiry,
            status: 'open',
            updatedAt: new Date().toISOString(),
          },
          {merge: true},
        ),
      );
    }

    await Promise.all(writes);
    res.json({success: true, processed: writes.length});
  } catch (err) {
    console.error('generateExpiryAlerts error', err);
    res.status(500).json({error: String(err)});
  }
});

// ── POST /generate-low-stock-alerts  (chamado pelo Cloud Scheduler) ───────────

app.post('/generate-low-stock-alerts', async (_req: Request, res: Response) => {
  try {
    const productsSnap = await db.collection('products').where('isActive', '==', true).get();
    const batchesSnap = await db
      .collection('batches')
      .where('status', '==', 'disponivel')
      .where('quantity', '>', 0)
      .get();

    const stockByProduct = new Map<string, number>();
    for (const batch of batchesSnap.docs) {
      const d = batch.data();
      const productId = d.productId as string;
      const qty = (d.quantity as number | undefined) ?? 0;
      stockByProduct.set(productId, (stockByProduct.get(productId) ?? 0) + qty);
    }

    const writes: Array<Promise<FirebaseFirestore.WriteResult>> = [];
    for (const product of productsSnap.docs) {
      const p = product.data();
      const minStock = (p.minimumStock as number | undefined) ?? 0;
      if (minStock <= 0) continue;

      const currentStock = stockByProduct.get(product.id) ?? 0;
      if (currentStock > minStock) continue;

      writes.push(
        db.collection('alerts').doc(`${product.id}_low_stock`).set(
          {
            type: 'low_stock',
            severity: 'warning',
            productId: product.id,
            productName: p.name,
            minimumStock: minStock,
            currentStock,
            status: 'open',
            updatedAt: new Date().toISOString(),
          },
          {merge: true},
        ),
      );
    }

    await Promise.all(writes);
    res.json({success: true, processed: writes.length});
  } catch (err) {
    console.error('generateLowStockAlerts error', err);
    res.status(500).json({error: String(err)});
  }
});

// ── POST /audit-sensitive-changes  (chamado pelo Eventarc — document.written) ─

app.post('/audit-sensitive-changes', async (req: Request, res: Response) => {
  try {
    // Eventarc envia DocumentEventData: { value, oldValue, updateMask }
    const eventData = req.body as {
      value?: {name?: string; fields?: Record<string, Record<string, unknown>>};
      oldValue?: {name?: string; fields?: Record<string, Record<string, unknown>>};
    };

    const docName = eventData.value?.name ?? eventData.oldValue?.name ?? '';
    const {collectionId, docId} = parseDocumentName(docName);

    const watched = new Set(['products', 'batches', 'users', 'settings']);
    if (!watched.has(collectionId)) {
      res.json({skipped: true});
      return;
    }

    const before = eventData.oldValue?.fields
      ? firestoreDocToObject(eventData.oldValue.fields)
      : null;
    const after = eventData.value?.fields
      ? firestoreDocToObject(eventData.value.fields)
      : null;

    await db.collection('audit_logs').add({
      collection: collectionId,
      documentId: docId,
      action: before == null ? 'create' : after == null ? 'delete' : 'update',
      before,
      after,
      performedBy: 'cloud_run',
      performedByName: 'Cloud Run',
      performedAt: new Date().toISOString(),
    });

    res.json({success: true});
  } catch (err) {
    console.error('auditSensitiveChanges error', err);
    res.status(500).json({error: String(err)});
  }
});

// ── POST /notify-on-alert-created  (chamado pelo Eventarc — document.created) ─

app.post('/notify-on-alert-created', async (req: Request, res: Response) => {
  try {
    const eventData = req.body as {
      value?: {name?: string; fields?: Record<string, Record<string, unknown>>};
    };

    const docName = eventData.value?.name ?? '';
    const alertId = docName.split('/').pop() ?? '';
    const data = eventData.value?.fields
      ? firestoreDocToObject(eventData.value.fields)
      : null;

    if (!data) {
      res.json({skipped: true});
      return;
    }

    const type = (data.type as 'expiry' | 'low_stock' | undefined) ?? 'expiry';
    const severity = (data.severity as string | undefined) ?? 'warning';
    const productName = (data.productName as string | undefined) ?? 'Produto';

    if (type === 'expiry') {
      const days = (data.daysToExpiry as number | undefined) ?? 0;
      await sendPushForAlert({
        title: severity === 'critical' ? 'Vencimento crítico' : 'Vencimento próximo',
        body: `${productName} vence em ${days} dia(s).`,
        type,
        severity,
        alertId,
      });
    } else {
      const currentStock = (data.currentStock as number | undefined) ?? 0;
      const minimumStock = (data.minimumStock as number | undefined) ?? 0;
      await sendPushForAlert({
        title: 'Estoque baixo',
        body: `${productName}: ${currentStock} em estoque (mínimo ${minimumStock}).`,
        type: 'low_stock',
        severity,
        alertId,
      });
    }

    res.json({success: true});
  } catch (err) {
    console.error('notifyOnAlertCreated error', err);
    res.status(500).json({error: String(err)});
  }
});

// ── start ─────────────────────────────────────────────────────────────────────

// ── POST /send-weekly-report  (chamado pelo Cloud Scheduler semanal) ──────────

interface ReportScheduleConfig {
  enabled: boolean;
  recipientEmail: string;
  dayOfWeek: number; // 0=Dom … 6=Sáb
  hour: number;
  minute: number;
}

async function buildReportHtml(db: FirebaseFirestore.Firestore): Promise<string> {
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  // Parallel data fetches
  const [productsSnap, batchesSnap, alertsSnap, movementsSnap] = await Promise.all([
    db.collection('products').where('isActive', '==', true).get(),
    db.collection('batches').where('status', '==', 'disponivel').where('quantity', '>', 0).get(),
    db.collection('alerts').where('status', '==', 'open').get(),
    db
      .collection('movements')
      .where('performedAt', '>=', weekAgo.toISOString())
      .orderBy('performedAt', 'desc')
      .limit(50)
      .get(),
  ]);

  const totalProducts = productsSnap.size;
  const totalBatches = batchesSnap.size;
  const totalStock = batchesSnap.docs.reduce(
    (sum, d) => sum + ((d.data().quantity as number | undefined) ?? 0),
    0,
  );

  const criticalAlerts = alertsSnap.docs.filter(
    (d) => d.data().severity === 'critical',
  ).length;
  const warningAlerts = alertsSnap.docs.filter(
    (d) => d.data().severity === 'warning',
  ).length;

  const totalMovements = movementsSnap.size;
  const movementRows = movementsSnap.docs
    .slice(0, 10)
    .map((d) => {
      const m = d.data();
      const date = new Date(m.performedAt as string).toLocaleDateString('pt-BR');
      return `<tr>
        <td style="padding:6px 10px;border-bottom:1px solid #eee">${date}</td>
        <td style="padding:6px 10px;border-bottom:1px solid #eee">${m.productName ?? '—'}</td>
        <td style="padding:6px 10px;border-bottom:1px solid #eee">${m.type ?? '—'}</td>
        <td style="padding:6px 10px;border-bottom:1px solid #eee;text-align:right">${m.quantity ?? 0}</td>
      </tr>`;
    })
    .join('');

  const dateStr = now.toLocaleDateString('pt-BR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>Relatório Semanal — EducaStock</title></head>
<body style="margin:0;padding:0;background:#f4f6fb;font-family:Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:32px 16px">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.08)">
        <!-- Header -->
        <tr><td style="background:linear-gradient(135deg,#1976D2 0%,#42A5F5 100%);padding:32px 40px;color:#fff">
          <h1 style="margin:0;font-size:24px;font-weight:700">📦 Relatório Semanal</h1>
          <p style="margin:8px 0 0;font-size:14px;opacity:.85">EducaStock — Casa da Criança</p>
          <p style="margin:4px 0 0;font-size:13px;opacity:.7">${dateStr}</p>
        </td></tr>
        <!-- KPI cards -->
        <tr><td style="padding:32px 40px">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td width="25%" style="text-align:center;padding:16px 8px;background:#f0f7ff;border-radius:8px">
                <div style="font-size:28px;font-weight:700;color:#1976D2">${totalProducts}</div>
                <div style="font-size:12px;color:#666;margin-top:4px">Produtos ativos</div>
              </td>
              <td width="4%"></td>
              <td width="25%" style="text-align:center;padding:16px 8px;background:#f0fff4;border-radius:8px">
                <div style="font-size:28px;font-weight:700;color:#2e7d32">${totalStock}</div>
                <div style="font-size:12px;color:#666;margin-top:4px">Itens em estoque</div>
              </td>
              <td width="4%"></td>
              <td width="25%" style="text-align:center;padding:16px 8px;background:#fff8e1;border-radius:8px">
                <div style="font-size:28px;font-weight:700;color:#f57c00">${warningAlerts}</div>
                <div style="font-size:12px;color:#666;margin-top:4px">Alertas aviso</div>
              </td>
              <td width="4%"></td>
              <td width="25%" style="text-align:center;padding:16px 8px;background:#fff0f0;border-radius:8px">
                <div style="font-size:28px;font-weight:700;color:#c62828">${criticalAlerts}</div>
                <div style="font-size:12px;color:#666;margin-top:4px">Alertas críticos</div>
              </td>
            </tr>
          </table>
          <!-- Movements summary -->
          <h2 style="margin:32px 0 12px;font-size:16px;color:#1a1a2e">Movimentações da semana (${totalMovements} no total)</h2>
          ${
            movementRows
              ? `<table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px">
              <thead>
                <tr style="background:#f4f6fb">
                  <th style="padding:8px 10px;text-align:left;color:#555">Data</th>
                  <th style="padding:8px 10px;text-align:left;color:#555">Produto</th>
                  <th style="padding:8px 10px;text-align:left;color:#555">Tipo</th>
                  <th style="padding:8px 10px;text-align:right;color:#555">Qtd</th>
                </tr>
              </thead>
              <tbody>${movementRows}</tbody>
            </table>`
              : '<p style="color:#999;font-size:13px">Nenhuma movimentação esta semana.</p>'
          }
          <!-- Footer -->
          <p style="margin:32px 0 0;font-size:12px;color:#aaa;text-align:center">
            Este relatório foi gerado automaticamente pelo EducaStock.<br>
            Para desativar, acesse Relatórios → Agendar relatório.
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

app.post('/send-weekly-report', async (_req: Request, res: Response) => {
  try {
    // 1. Read schedule config
    const scheduleDoc = await db.collection('settings').doc('report_schedule').get();
    if (!scheduleDoc.exists) {
      res.json({skipped: true, reason: 'no schedule config'});
      return;
    }
    const config = scheduleDoc.data() as ReportScheduleConfig | undefined;
    if (!config?.enabled) {
      res.json({skipped: true, reason: 'schedule disabled'});
      return;
    }
    if (!config.recipientEmail) {
      res.json({skipped: true, reason: 'no recipient email'});
      return;
    }

    // 2. Build report
    const html = await buildReportHtml(db);

    // 3. Send email via SMTP (configured via Cloud Run env vars)
    const smtpHost = process.env.SMTP_HOST ?? 'smtp.gmail.com';
    const smtpPort = parseInt(process.env.SMTP_PORT ?? '587', 10);
    const smtpUser = process.env.SMTP_USER ?? '';
    const smtpPass = process.env.SMTP_PASS ?? '';
    const senderName = process.env.SMTP_SENDER_NAME ?? 'EducaStock';

    if (!smtpUser || !smtpPass) {
      console.warn('[sendWeeklyReport] SMTP_USER/SMTP_PASS not configured');
      res.status(500).json({error: 'SMTP credentials not configured'});
      return;
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: {user: smtpUser, pass: smtpPass},
    });

    await transporter.sendMail({
      from: `"${senderName}" <${smtpUser}>`,
      to: config.recipientEmail,
      subject: `📦 Relatório Semanal EducaStock — ${new Date().toLocaleDateString('pt-BR')}`,
      html,
    });

    console.log(`[sendWeeklyReport] Sent to ${config.recipientEmail}`);
    res.json({success: true, sentTo: config.recipientEmail});
  } catch (err) {
    console.error('sendWeeklyReport error', err);
    res.status(500).json({error: String(err)});
  }
});

// ── start ─────────────────────────────────────────────────────────────────────

const PORT = process.env.PORT ?? 8080;
app.listen(PORT, () => console.log(`educastock-functions listening on port ${PORT}`));
