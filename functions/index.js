const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

// Initialize Firebase Admin
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Cloud Function: sendPushNotification
 * Triggers when a NEW document is created in 'notifications' collection.
 * Reads the user's FCM token and sends a push notification.
 * This works even when the app is COMPLETELY CLOSED.
 */
exports.sendPushNotification = onDocumentCreated(
    "notifications/{notifId}",
    async (event) => {
      const data = event.data.data();
      if (!data) return;

      const userId = data.userId;
      if (!userId) return;

      try {
        // Get user's FCM token from Firestore
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const token = userData.fcmToken;
        if (!token) {
          console.log(`No FCM token for user ${userId}`);
          return;
        }

        const isEmergency = data.type === "emergency";
        const title = data.title || "LifeLink";
        const body = data.body || "";

        // Build the FCM message
        const message = {
          token: token,
          notification: {
            title: title,
            body: body,
          },
          data: {
            route: data.requestId
              ? `/request-detail?id=${data.requestId}`
              : "",
            type: data.type || "general",
            requestId: data.requestId || "",
          },
          android: {
            priority: isEmergency ? "high" : "normal",
            notification: {
              channelId: isEmergency ?
                "emergency_channel" :
                "general_channel",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              priority: isEmergency ? "max" : "high",
            },
          },
        };

        // Send the push notification
        const response = await messaging.send(message);
        console.log(
            `✅ Push sent to ${userId}: ${title} (${response})`,
        );
      } catch (error) {
        // If token is invalid, clean it up
        if (
          error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered"
        ) {
          console.log(`Removing invalid token for ${userId}`);
          await db.collection("users").doc(userId).update({
            fcmToken: null,
          });
        } else {
          console.error(`Error sending push to ${userId}:`, error);
        }
      }
    },
);
