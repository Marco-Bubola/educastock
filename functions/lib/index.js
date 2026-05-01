"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifyOnAlertCreated = exports.auditSensitiveChanges = exports.generateLowStockAlerts = exports.generateExpiryAlerts = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
admin.initializeApp();
const db = admin.firestore();
async function sendPushForAlert(params) {
    const tokensSnap = await db.collection('device_tokens').get();
    const tokens = tokensSnap.docs
        .map((d) => d.data().token?.trim())
        .filter((t) => !!t)
        .slice(0, 500);
    if (tokens.length === 0)
        return;
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
exports.generateExpiryAlerts = (0, scheduler_1.onSchedule)({
    schedule: 'every day 07:00',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
}, async () => {
    const settingsDoc = await db.collection('settings').doc('alerts').get();
    const criticalDays = settingsDoc.data()?.criticalDays ?? 7;
    const warningDays = settingsDoc.data()?.warningDays ?? 30;
    const today = new Date();
    const warningLimit = new Date(today);
    warningLimit.setDate(today.getDate() + warningDays);
    const batchesSnap = await db
        .collection('batches')
        .where('status', '==', 'disponivel')
        .where('noExpiry', '==', false)
        .where('quantity', '>', 0)
        .get();
    const writes = [];
    for (const doc of batchesSnap.docs) {
        const data = doc.data();
        const expiryRaw = data.expiryDate;
        if (!expiryRaw)
            continue;
        const expiry = new Date(expiryRaw);
        if (Number.isNaN(expiry.getTime()) || expiry > warningLimit)
            continue;
        const daysToExpiry = Math.ceil((expiry.getTime() - today.getTime()) / 86400000);
        const severity = daysToExpiry <= criticalDays ? 'critical' : 'warning';
        const alertId = `${doc.id}_${severity}`;
        writes.push(db.collection('alerts').doc(alertId).set({
            type: 'expiry',
            severity,
            batchId: doc.id,
            productId: data.productId,
            productName: data.productName,
            daysToExpiry,
            status: 'open',
            updatedAt: new Date().toISOString(),
        }, { merge: true }));
    }
    await Promise.all(writes);
});
exports.generateLowStockAlerts = (0, scheduler_1.onSchedule)({
    schedule: 'every day 07:10',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
}, async () => {
    const productsSnap = await db.collection('products').where('isActive', '==', true).get();
    const batchesSnap = await db.collection('batches').where('status', '==', 'disponivel').where('quantity', '>', 0).get();
    const stockByProduct = new Map();
    for (const batch of batchesSnap.docs) {
        const d = batch.data();
        const productId = d.productId;
        const qty = d.quantity ?? 0;
        stockByProduct.set(productId, (stockByProduct.get(productId) ?? 0) + qty);
    }
    const writes = [];
    for (const product of productsSnap.docs) {
        const p = product.data();
        const minStock = p.minimumStock ?? 0;
        if (minStock <= 0)
            continue;
        const currentStock = stockByProduct.get(product.id) ?? 0;
        if (currentStock > minStock)
            continue;
        writes.push(db.collection('alerts').doc(`${product.id}_low_stock`).set({
            type: 'low_stock',
            severity: 'warning',
            productId: product.id,
            productName: p.name,
            minimumStock: minStock,
            currentStock,
            status: 'open',
            updatedAt: new Date().toISOString(),
        }, { merge: true }));
    }
    await Promise.all(writes);
});
exports.auditSensitiveChanges = (0, firestore_1.onDocumentWritten)({
    document: '{collectionId}/{docId}',
    region: 'southamerica-east1',
}, async (event) => {
    const collectionId = event.params.collectionId;
    const docId = event.params.docId;
    const watched = new Set(['products', 'batches', 'users', 'settings']);
    if (!watched.has(collectionId))
        return;
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
});
exports.notifyOnAlertCreated = (0, firestore_1.onDocumentCreated)({
    document: 'alerts/{alertId}',
    region: 'southamerica-east1',
}, async (event) => {
    const alertId = event.params.alertId;
    const data = event.data?.data();
    if (!data)
        return;
    const type = data.type ?? 'expiry';
    const severity = data.severity ?? 'warning';
    const productName = data.productName ?? 'Produto';
    if (type === 'expiry') {
        const days = data.daysToExpiry ?? 0;
        await sendPushForAlert({
            title: severity === 'critical' ? 'Vencimento crítico' : 'Vencimento próximo',
            body: `${productName} vence em ${days} dia(s).`,
            type,
            severity,
            alertId,
        });
        return;
    }
    const currentStock = data.currentStock ?? 0;
    const minimumStock = data.minimumStock ?? 0;
    await sendPushForAlert({
        title: 'Estoque baixo',
        body: `${productName}: ${currentStock} em estoque (mínimo ${minimumStock}).`,
        type: 'low_stock',
        severity,
        alertId,
    });
});
