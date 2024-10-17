import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'chatpage.dart';

class ChatCard extends StatefulWidget {
  final String username;
  final String userId;
  final bool defaultPic;

  const ChatCard({
    super.key,
    required this.username,
    required this.userId,
    required this.defaultPic,
  });

  @override
  ChatCardState createState() => ChatCardState();
}

class ChatCardState extends State<ChatCard> {
  String? _imageUrl;
  bool _loading = true;
  String lastMessage = 'Loading...'; // To store the last message
  Timestamp? lastMessageTime; // To store the time of the last message

  @override
  void initState() {
    super.initState();
    if (!widget.defaultPic) {
      _fetchImageUrl();
    } else {
      _loading = false; // No need to load if it's a default picture
    }

    // Fetch the last message preview
    _fetchLastMessage();
  }

  Future<void> _fetchImageUrl() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('users/${widget.userId}/zed.jpg');
      final url = await ref.getDownloadURL();
      setState(() {
        _imageUrl = url;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _imageUrl = null; // Set to null in case of an error
        _loading = false; // Stop loading even if there was an error
      });
    }
  }

  Future<void> _fetchLastMessage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Fetch the last message for this chat from Firestore, ordered by timestamp
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .collection('chats')
          .doc(widget.userId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var lastMsgData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        setState(() {
          lastMessage = lastMsgData['text'] ?? 'No message yet'; // Display message text
          lastMessageTime = lastMsgData['timestamp'];
        });
      } else {
        setState(() {
          lastMessage = 'No messages yet'; // If no messages
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDarkMode ? Colors.grey : Colors.black,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.transparent,
          child: _loading
              ? CircularProgressIndicator()
              : widget.defaultPic
              ? Image.asset('assets/defprofile.jpg') // Default asset image
              : _imageUrl != null
              ? CachedNetworkImage(
            imageUrl: _imageUrl!,
            imageBuilder: (context, imageProvider) => CircleAvatar(
              radius: 25,
              backgroundImage: imageProvider,
            ),
            placeholder: (context, url) => CircularProgressIndicator(),
            errorWidget: (context, url, error) => Image.asset(
              'assets/defprofile.jpg',
              fit: BoxFit.cover,
            ),
          )
              : Image.asset(
            'assets/defprofile.jpg',
            fit: BoxFit.cover,
          ),
        ),
        title: Text(widget.username),
        subtitle: Text(lastMessage), // Displaying the last message preview
        trailing: lastMessageTime != null
            ? Text(
          _formatTimestamp(lastMessageTime!),
          style: TextStyle(color: Colors.grey),
        )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper function to format the timestamp into HH:mm
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}


bool isValidEmail(String email) {
  const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  return RegExp(emailRegex).hasMatch(email);
}

Future<bool> checkIfEmailExists(String email) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();
    return querySnapshot.exists;
  } catch (_) {
    return false;
  }
}
