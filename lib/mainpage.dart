import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';
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

  List<Map<String, dynamic>> _chatUsers = [];

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat with this user already exists.')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid email or user does not exist')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user details')),
      );
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

            chatUsers.add({
              'userId': chatPartnerEmail,
              'username': username,
              'defaultPic': true,
            });
          }
        }

        mounted ? setState(() => _chatUsers = chatUsers) : null;
      });
    } catch (_) {}
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    await prefs.setBool('remember_me', false);
  }


  // Fetching the user's details (username and email)
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
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchChatPartners();
    fetchUserDetails();
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
            // Customized UserAccountsDrawerHeader with responsive colors
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.blue[900] : Colors.blue[200], // Custom background
              ),
              accountName: Text(
                _username ?? 'Fetching username...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black, // Responsive text color
                ),
              ),
              accountEmail: Text(
                _email ?? 'Fetching email...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87, // Responsive text color
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: isDarkMode ? Colors.white : Colors.grey[200],
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: isDarkMode ? Colors.black : Colors.blueGrey[700], // Responsive icon color
                ),
              ),
            ),
            ListTile(
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black, // Responsive text color
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
                color: isDarkMode ? Colors.white : Colors.black, // Responsive icon color
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black, // Responsive text color
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
        );
      },
    );
  }
}
