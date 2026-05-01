import * as admin from 'firebase-admin';
import {onDocumentCreated, onDocumentWritten} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';

admin.initializeApp();

const db = admin.firestore();

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
    notification: {
      title: params.title,
      body: params.body,
    },
    data: {
      route: 'alerts',
      type: params.type,
      severity: params.severity,
      alertId: params.alertId,
    },
  });
}

export const generateExpiryAlerts = onSchedule(
  {
    schedule: 'every day 07:00',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
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
  },
);

export const generateLowStockAlerts = onSchedule(
  {
    schedule: 'every day 07:10',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
    const productsSnap = await db.collection('products').where('isActive', '==', true).get();
    const batchesSnap = await db.collection('batches').where('status', '==', 'disponivel').where('quantity', '>', 0).get();

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
  },
);

export const auditSensitiveChanges = onDocumentWritten(
  {
    document: '{collectionId}/{docId}',
    region: 'southamerica-east1',
  },
  async (event) => {
    const collectionId = event.params.collectionId as string;
    const docId = event.params.docId as string;

    const watched = new Set(['products', 'batches', 'users', 'settings']);
    if (!watched.has(collectionId)) return;

    const before = event.data?.before?.data() ?? null;
    const after = event.data?.after?.data() ?? null;

    await db.collection('audit_logs').add({
      collection: collectionId,
      documentId: docId,
      action: before == null ? 'create' : after == null ? 'delete' : 'update',
      before,
      after,
      performedBy: 'cloud_function',
      performedByName: 'Cloud Function',
      performedAt: new Date().toISOString(),
    });
  },
);

export const notifyOnAlertCreated = onDocumentCreated(
  {
    document: 'alerts/{alertId}',
    region: 'southamerica-east1',
  },
  async (event) => {
    const alertId = event.params.alertId as string;
    const data = event.data?.data();
    if (!data) return;

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
      return;
    }

    const currentStock = (data.currentStock as number | undefined) ?? 0;
    const minimumStock = (data.minimumStock as number | undefined) ?? 0;
    await sendPushForAlert({
      title: 'Estoque baixo',
      body: `${productName}: ${currentStock} em estoque (mínimo ${minimumStock}).`,
      type: 'low_stock',
      severity,
      alertId,
    });
  },
);
