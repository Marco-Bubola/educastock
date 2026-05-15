import * as admin from 'firebase-admin';
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

const PORT = process.env.PORT ?? 8080;
app.listen(PORT, () => console.log(`educastock-functions listening on port ${PORT}`));
