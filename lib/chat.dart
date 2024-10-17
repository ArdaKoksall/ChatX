import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';

Future<void> sendMessage(String senderMail, String receiverMail, String messageText) async {
  final message = {
    'senderId': senderMail,
    'text': messageText,
    'timestamp': FieldValue.serverTimestamp(),
  };

  // Add the message to the sender's messages collection
  await FirebaseFirestore.instance
      .collection('users')
      .doc(senderMail)
      .collection('chats')
      .doc(receiverMail)
      .collection('messages')
      .add(message);

  // Add the message to the receiver's messages collection
  await FirebaseFirestore.instance
      .collection('users')
      .doc(receiverMail)
      .collection('chats')
      .doc(senderMail)
      .collection('messages')
      .add(message);

  // Update last message for the sender
  await FirebaseFirestore.instance
      .collection('users')
      .doc(senderMail)
      .collection('chats')
      .doc(receiverMail)
      .update({
    'lastMessage': messageText,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Update last message for the receiver
  await FirebaseFirestore.instance
      .collection('users')
      .doc(receiverMail)
      .collection('chats')
      .doc(senderMail)
      .update({
    'lastMessage': messageText,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
