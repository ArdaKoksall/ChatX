import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common.dart';
import 'login.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadThemeFromFirestore();
  }

  Future<void> _loadThemeFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>;
      setState(() {
        isDarkMode = userData['theme'] ?? true;
      });
    }
  }

  Future<void> _updateThemeInFirestore(bool newTheme) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'theme': newTheme});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatX',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainPage(
        toggleTheme: _toggleTheme,
        isDarkMode: isDarkMode,
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
      _updateThemeInFirestore(isDarkMode);
    });
  }
}

class MainPage extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const MainPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isAddingUser = false;

  String? _username;
  String? _email;
  String? _imageUrl;
  bool _defaultProfilePic = true;

  List<Map<String, dynamic>> _chatUsers = [];

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    fetchChatPartners();
  }

  Future<void> fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>;
      setState(() {
        _username = userData['username'] ?? 'No Username';
        _email = user.email;
        _imageUrl = userData['imageUrl'];
        _defaultProfilePic = userData['defaultProfilePic'] ?? true;
      });
    }
  }

  Future<void> uploadProfileImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      final file = result.files.single;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String fileName;

        // Web logic: using file name directly
        if (kIsWeb) {
          fileName = file.name;
        } else {
          // Mobile logic: using path's filename
          fileName = file.path!.split('/').last;
        }

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('images/${user.uid}/$fileName');

        // Upload file (for mobile and web)
        if (kIsWeb) {
          await storageRef.putData(file.bytes!);
        } else {

        }

        final imageUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .update({
          'imageUrl': imageUrl,
          'defaultProfilePic': false,
        });

        setState(() {
          _imageUrl = imageUrl;
          _defaultProfilePic = false;
        });
      }
    }
  }

  Future<void> removeProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({
        'defaultProfilePic': true,
      });
      setState(() {
        _defaultProfilePic = true;
        _imageUrl = null;
      });
    }
  }

  Future<void> fetchChatPartners() async {
    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection('chats')
          .snapshots()
          .listen((snapshot) async {
        List<Map<String, dynamic>> chatUsers = [];

        for (var doc in snapshot.docs) {
          String chatPartnerEmail = doc.id;

          DocumentSnapshot partnerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(chatPartnerEmail)
              .get();

          if (partnerDoc.exists) {
            var partnerData = partnerDoc.data() as Map<String, dynamic>;
            String username = partnerData['username'];
            bool defaultPic = partnerData['defaultProfilePic'] ?? true; // Fetch defaultPic

            // Add imageUrl only if it's available, else use default
            String? imageUrl = defaultPic ? null : partnerData['imageUrl'];

            chatUsers.add({
              'userId': chatPartnerEmail,
              'username': username,
              'defaultPic': defaultPic,
              'imageUrl': imageUrl, // Add imageUrl to the chatUsers map
            });
          }
        }

        mounted ? setState(() => _chatUsers = chatUsers) : null;
      });
    } catch (_) {}
  }


  Future<void> fetchUserAndCreateChat(String email) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user?.email == email) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You cannot add yourself as a chat partner.')),
        );
        return;
      }

      if (isValidEmail(email) && await checkIfEmailExists(email)) {
        bool chatExists = await _checkIfChatExists(user!.email!, email);
        if (chatExists) {
          mounted ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chat already exists.'),
          )) : null;
          return;
        }

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .get();
        var userData = userDoc.data() as Map<String, dynamic>;
        String username = userData['username'];
        bool defaultPic = userData['defaultProfilePic'] ?? true;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection('chats')
            .doc(email)
            .set({
          'username': username,
          'timestamp': FieldValue.serverTimestamp(),
          'defaultPic': defaultPic
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('chats')
            .doc(user.email)
            .set({
          'username': userData['username'],
          'timestamp': FieldValue.serverTimestamp(),
          'defaultPic': true
        });

        setState(() {
          _chatUsers.add({
            'username': username,
            'userId': email,
            'defaultPic': defaultPic,
          });
          _isAddingUser = false;
        });
      } else {
        mounted ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid email or user does not exist.'),
        )) : null;
      }
    } catch (_) {
      mounted ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to add user to chat.'),
      )) : null;
    }
  }

  Future<bool> _checkIfChatExists(String currentUserEmail, String newChatUserEmail) async {
    DocumentSnapshot chatDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserEmail)
        .collection('chats')
        .doc(newChatUserEmail)
        .get();
    return chatDoc.exists;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('ChatX'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _isAddingUser = true;
              });
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {
            _scaffoldKey.currentState!.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.blue[900] : Colors.blue[200],
              ),
              accountName: Text(
                _username ?? 'Fetching username...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              accountEmail: Text(
                _email ?? 'Fetching email...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: isDarkMode ? Colors.white : Colors.grey[200],
                child: _defaultProfilePic
                    ? Image.asset('assets/defprofile.jpg')
                    : _imageUrl != null
                    ? Image.network(_imageUrl!)
                    : Icon(Icons.person),
              ),
            ),
            ListTile(
              title: Text(
                'Upload Profile Picture',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.upload),
                onPressed: uploadProfileImage,
              ),
            ),
            ListTile(
              title: Text(
                'Remove Profile Picture',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.remove_circle),
                onPressed: removeProfileImage,
              ),
            ),
            ListTile(
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              trailing: Switch(
                value: widget.isDarkMode,
                onChanged: (value) {
                  widget.toggleTheme();
                },
              ),
            ),
            Spacer(),
            ListTile(
              leading: Icon(
                Icons.logout_outlined,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                _clearCredentials();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          ChatList(chatUsers: _chatUsers),
          if (_isAddingUser)
            Center(
              child: AlertDialog(
                title: Text('Enter User Email'),
                content: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(hintText: 'Enter user email'),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isAddingUser = false;
                      });
                    },
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      String email = _emailController.text.trim();
                      if (email.isNotEmpty) {
                        fetchUserAndCreateChat(email);
                        _emailController.clear();
                      }
                    },
                    child: Text('Add User'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    await prefs.setBool('remember_me', false);
  }
}

class ChatList extends StatelessWidget {
  final List<Map<String, dynamic>> chatUsers;

  const ChatList({super.key, required this.chatUsers});

  @override
  Widget build(BuildContext context) {
    if (chatUsers.isEmpty) {
      return Center(
        child: Text(
          'No chat partners yet. Add a new chat!',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: chatUsers.length,
      itemBuilder: (context, index) {
        return ChatCard(
          username: chatUsers[index]['username'],
          userId: chatUsers[index]['userId'],
          defaultPic: chatUsers[index]['defaultPic'],
          imageUrl: chatUsers[index]['imageUrl'], // Include imageUrl here
        );
      },
    );
  }
}

