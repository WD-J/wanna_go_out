import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/painting.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_auth_buttons/flutter_auth_buttons.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_ui/firestore_ui.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_responsive_screen/flutter_responsive_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:random_string/random_string.dart';
import 'package:image_ink_well/image_ink_well.dart';
import 'package:pigment/pigment.dart';
import 'package:flutter_launcher_icons/android.dart';
import 'package:flutter_launcher_icons/constants.dart';
import 'package:flutter_launcher_icons/custom_exceptions.dart';
import 'package:flutter_launcher_icons/ios.dart';
import 'package:flutter_launcher_icons/main.dart';
import 'package:flutter_launcher_icons/xml_templates.dart';
import 'package:flutter_responsive_screen/flutter_responsive_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() => runApp(MyApp());

final GoogleSignIn _googleSignIn = GoogleSignIn();
final FirebaseAuth _auth = FirebaseAuth.instance;

String username;
Future<FirebaseUser> getFirebaseUser() async {
  FirebaseUser user = await FirebaseAuth.instance.currentUser();

  if (user != null) {
    await Firestore.instance.collection("users").document(user.uid).get().then((data) async {
      return username = data.data['username'].toString();
    });
    return user;
  } else {
    return null;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<FirebaseUser>(
        future: getFirebaseUser(),
        builder: (BuildContext context, AsyncSnapshot<FirebaseUser> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: Text('Loading...'));
            default:
              if (snapshot.hasError)
                return new Text('Error: ${snapshot.error}');
              else if (snapshot.hasData) {
                return HomePage(uid: snapshot.data.uid, username: username);
              }
              return Sign();
          }
        },
      ),
    );
  }
}

// This piece of code is for when you want to prompt the user for either taking an image, or selecting a local image.
/*
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Pigment.fromString("ffe34c"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                                IconButton(
                                  icon: Icon(Icons.camera_alt),
                                  onPressed: () {
                                    choosePfp(true);
                                    Navigator.pop(context);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.image),
                                  onPressed: () {
                                    choosePfp(false);
                                    Navigator.pop(context);
                                  },
                                ),
                              ]),
                            ],
                          ),
                        );
                      },
                    );
 */

class Sign extends StatefulWidget {
  @override
  _SignState createState() => _SignState();
}

class _SignState extends State<Sign> {
  File _file;
  var fileUrl;
  var fileExtension;

  Future choosePfp(bool isCamera) async {
    File file;
    if (isCamera == true) {
      file = await ImagePicker.pickImage(source: ImageSource.camera);
    } else {
      file = await ImagePicker.pickImage(source: ImageSource.gallery);
    }

    setState(() {
      _file = file;
      fileExtension = p.extension(file.toString()).split('?').first.replaceFirst(".", "").replaceFirst("'", "");
    });
  }

  Future uploadPfp(BuildContext context) async {
    final FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final String userID = user.uid.toString();
    String fileId = userID + " - " + randomAlphaNumeric(5);
    StorageReference reference = FirebaseStorage.instance.ref().child("$fileId");

    StorageUploadTask uploadTask = reference.putFile(
      _file,
      StorageMetadata(
        // Here you need to update the type depending on what the user wants to upload.
        contentType: "image" + '/' + fileExtension,
      ),
    );
    StorageTaskSnapshot taskSnapshot = await uploadTask.onComplete;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();

    return fileUrl = downloadUrl;
  }

  FirebaseUser user;
  // Google user authentication
  Future<FirebaseUser> _googleAuth() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.getCredential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      user = (await _auth.signInWithCredential(credential)).user;
    } catch (e) {
      print('Google sign up / in unsuccessful: ' + e);
    } finally {
      if (user != null) {
        usernameController.text = usernameController.text.trim();

        _file != null ? await uploadPfp(context) : _file = null;

        String username = usernameController.text.isEmpty || usernameController.text == ' '
            ? user.email.split('@').first
            : usernameController.text;

        if (Firestore.instance.collection('users').document(user.uid).toString().isEmpty) {
          Firestore.instance.collection('users').document(user.uid).setData({
            'username': username,
            'pfp': fileUrl,
            'gender': chosenGender == 0 ? 'male' : 'female',
            'creationTimestamp': Timestamp.now(),
            'matchedWith': [user.uid],
          });
        }

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (BuildContext context) => HomePage(uid: user.uid, username: username)));
      } else {
        // sign up unsuccessful
        // ex: prompt the user to try again
      }
    }
    return user;
  }

  // Email Sign up
  Future<FirebaseUser> _handleEmailSignUp() async {
    try {
      user = (await _auth.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      ))
          .user;
    } catch (e) {
      print('Sign up unsuccessful: ' + e);
    } finally {
      if (user != null) {
        usernameController.text = usernameController.text.trim();

        _file != null ? await uploadPfp(context) : _file = null;

        String username = usernameController.text.isEmpty || usernameController.text == ' '
            ? user.email.split('@').first
            : usernameController.text;

        Firestore.instance.collection('users').document(user.uid).setData({
          'username': username,
          'pfp': fileUrl,
          'gender': chosenGender == 0 ? 'male' : 'female',
          'creationTimestamp': Timestamp.now(),
          'matchedWith': [user.uid],
        });

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (BuildContext context) => HomePage(uid: user.uid, username: username)));
      } else {
        // sign up unsuccessful
        // ex: prompt the user to try again
      }
    }
    return user;
  }

  // Email Sign in
  Future<FirebaseUser> _handleEmailSignIn() async {
    try {
      user = (await _auth.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      ))
          .user;

      String username;
      await Firestore.instance.collection("users").document(user.uid).get().then((data) async {
        return username = data.data['username'];
      });

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (BuildContext context) => HomePage(uid: user.uid, username: username)));
    } catch (e) {
      print('Sign in unsuccessful: ' + e);
    }
    return user;
  }

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 0 = Male & 1 = Female
  var chosenGender;
  var selectedHighlight = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.only(top: 50, left: 50, right: 50),
        child: Column(
          children: <Widget>[
            Text(
              "Wanna go out?",
            ),
            Padding(padding: EdgeInsets.all(10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                CircleImageInkWell(
                  size: 50,
                  onPressed: () {
                    choosePfp(false);
                  },
                  image: _file == null
                      ? AssetImage(
                          'assets/account_circle.png',
                        )
                      : FileImage(_file),
                  splashColor: Colors.white30,
                ),
                Material(
                  elevation: 5,
                  color: selectedHighlight == 1 ? Colors.blue : Colors.white,
                  child: MaterialButton(
                    onPressed: () {
                      chosenGender = 0;
                      setState(() {
                        selectedHighlight = 1;
                      });
                    },
                    child: Text("Male"),
                  ),
                ),
                Material(
                  elevation: 5,
                  color: selectedHighlight == 2 ? Colors.pink : Colors.white,
                  child: MaterialButton(
                    onPressed: () {
                      chosenGender = 1;
                      setState(() {
                        selectedHighlight = 2;
                      });
                    },
                    child: Text("Female"),
                  ),
                ),
              ],
            ),
            Padding(padding: EdgeInsets.all(10)),
            Text("username"),
            TextFormField(
              controller: usernameController,
              keyboardType: TextInputType.text,
            ),
            Padding(padding: EdgeInsets.all(25)),
            Text("email"),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            Padding(padding: EdgeInsets.all(25)),
            Text("Password"),
            TextFormField(
              controller: passwordController,
              keyboardType: TextInputType.visiblePassword,
            ),
            Padding(padding: EdgeInsets.all(25)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Material(
                  elevation: 5.0,
                  child: MaterialButton(
                    onPressed: _handleEmailSignIn,
                    child: Text("Sign In", textAlign: TextAlign.center),
                  ),
                ),
                Material(
                  elevation: 5.0,
                  child: MaterialButton(
                    onPressed: _handleEmailSignUp,
                    child: Text("Sign Up", textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
            Padding(padding: EdgeInsets.all(25)),
            GoogleSignInButton(onPressed: _googleAuth),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key key, this.uid, this.username}) : super(key: key);
  final String uid;
  final String username;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var stream;

  Future _findChat() async {
    try {
      FirebaseUser user = await _auth.currentUser();
      // Get users
      final snapshot = await Firestore.instance.collection('users').getDocuments();
      var docs = snapshot.documents;

      // Find all users that haven't matched with you and vice versa, excluding yourself via user.uid
      docs.removeWhere((item) => item.data['matchedWith'].contains(user.uid));
      // Select the first user you haven't matched with, that you're proceeding to match with
      final selectedUser = docs[0].documentID;

      // Get your username
      String username;
      await Firestore.instance.collection("users").document(user.uid).get().then((data) async {
        return username = data.data['username'];
      });

      // Get the username of the selectedUser
      String selectedUserUsername;
      await Firestore.instance.collection('users').document(selectedUser).get().then((data) async {
        return selectedUserUsername = data.data['username'];
      });

      // Generate a chat with the name of your uid and your username, and the first selectedUser uid and username,
      // separated by '|'
      await Firestore.instance.collection('chats').document(user.uid + '|' + selectedUser).setData({
        'members': [user.uid, selectedUser],
        'memberUsernames': [username, selectedUserUsername],
        'messages': [],
      });

      // Find your user document
      var yourUserDoc = Firestore.instance.collection('users').document(user.uid);
      yourUserDoc.get().then((data) async {
        // Add the selectedUser(uid) (that just generated a chat with) to your list of previously matched with users.
        await Firestore.instance.collection('users').document(user.uid).updateData({
          'matchedWith': FieldValue.arrayUnion([selectedUser]),
        });
      });

      // Find the selected user's document
      var selectedUserDoc = Firestore.instance.collection('users').document(selectedUser);
      selectedUserDoc.get().then((data) async {
        // Add your user (uid) to the selected user's list of previously matched with users.
        await Firestore.instance.collection('users').document(selectedUser).updateData({
          'matchedWith': FieldValue.arrayUnion([user.uid]),
        });
      });

      // Set the stream that gets passed on to chatScreen by finding the generated chat.
      stream = Firestore.instance.collection('chats').document(user.uid + '|' + selectedUser).snapshots();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => ChatPage(
            stream: stream,
            docID: user.uid + '|' + selectedUser,
            uid: user.uid,
            username: username,
            selectedUid: selectedUser,
            selectedUserUsername: selectedUserUsername,
          ),
        ),
      );
    } catch (e) {
      if (e.toString().contains('RangeError')) {
        print("All current users have been previously matched with: " + e.toString());
      }
      // Different error message handling here: else if()...
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: SizedBox(
        width: 100,
        height: 100,
        child: RaisedButton(
          elevation: 3,
          color: Colors.blue,
          highlightColor: Colors.transparent,
          onPressed: () {
            _findChat();
          },
          shape: CircleBorder(),
          child: Text(
            "Find Human",
            style: TextStyle(fontFamily: 'Courier', color: Colors.white, fontSize: 15),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: Firestore.instance
            .collection('chats')
            .where('members', arrayContains: widget.uid)
            // .where('messages', isGreaterThan: [])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('Error: ${snapshot.error}');
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Text('Loading...');
            default:
              List list = snapshot.data.documents.toList();
              return list != null
                  ? ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        List selectedUid = snapshot.data.documents[index].documentID.split('|');
                        selectedUid.remove(widget.uid);

                        List selectedUserUsername = snapshot.data.documents[index]['memberUsernames'];
                        selectedUserUsername.remove(widget.username);
                        return MaterialButton(
                          height: 100,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) => ChatPage(
                                  stream: Firestore.instance
                                      .collection('chats')
                                      .document(snapshot.data.documents[index].documentID)
                                      .snapshots(),
                                  docID: snapshot.data.documents[index].documentID,
                                  uid: widget.uid,
                                  username: widget.username,
                                  selectedUid: selectedUid.join(),
                                  selectedUserUsername: selectedUserUsername.join(),
                                ),
                              ),
                            );
                          },
                          child: Text(selectedUserUsername.join()),
                        );
                      },
                    )
                  : Center(
                      child: Text('Empty'),
                    );
          }
        },
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  ChatPage({Key key, this.stream, this.docID, this.uid, this.username, this.selectedUid, this.selectedUserUsername})
      : super(key: key);
  final Stream stream;
  final String docID;
  final String uid;
  final String username;
  final String selectedUid;
  final String selectedUserUsername;

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  FocusNode _focus = FocusNode();
  TextEditingController msgController = TextEditingController();
  var isSending = false;

  File _file;
  var fileUrl;
  var fileExtension;

  void sendMsg() async {
    try {
      _file != null ? await sendMMS(context) : _file = null;

      FirebaseUser user = await _auth.currentUser();
      Firestore.instance.collection('chats').document(widget.docID).setData({
        'messages': FieldValue.arrayUnion([
          {
            'mms': fileUrl,
            'message': msgController.text.isEmpty ? null : msgController.text,
            // 'sender': userName,
            // 'senderimg': userPfp,
            'senderid': user.uid,
            'timeSent': DateTime.now().toUtc(),
          }
        ])
      }, merge: true);

      setState(() {
        msgController.clear();
        fileUrl = null;
        _file = null;
        fileExtension = null;
        isSending = false;
      });
    } catch (e) {
      print('Error: ' + e);
      // sending unsuccessful - tell user?
    }
  }

  Future chooseMMS(bool isCamera) async {
    File file;
    if (isCamera == true) {
      file = await ImagePicker.pickImage(source: ImageSource.camera);
    } else {
      file = await ImagePicker.pickImage(source: ImageSource.gallery);
    }

    setState(() {
      _file = file;
      fileExtension = p.extension(file.toString()).split('?').first.replaceFirst(".", "").replaceFirst("'", "");
    });
  }

  Future sendMMS(BuildContext context) async {
    setState(() {
      isSending = true;
    });

    final FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final String userID = user.uid.toString();
    String fileId = userID + " - " + randomAlphaNumeric(5);
    StorageReference reference = FirebaseStorage.instance.ref().child("$fileId");

    StorageUploadTask uploadTask = reference.putFile(
      _file,
      StorageMetadata(
        // Here you need to update the type depending on what the user wants to upload.
        contentType: "image" + '/' + fileExtension,
      ),
    );
    StorageTaskSnapshot taskSnapshot = await uploadTask.onComplete;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();

    return fileUrl = downloadUrl;
  }

  @override
  Widget build(BuildContext context) {
    final Function wp = Screen(MediaQuery.of(context).size).wp;
    final Function hp = Screen(MediaQuery.of(context).size).hp;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedUserUsername),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder(
              stream: widget.stream,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Text(
                    'Error: ${snapshot.error}',
                  );
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return Text('Loading...');
                  default:
                    List list = snapshot.data['messages'].reversed.toList();
                    return list != null
                        ? ListView.builder(
                            reverse: true,
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              return Column(
                                crossAxisAlignment: list[index]['senderid'] == widget.uid
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: <Widget>[
                                  // Image
                                  list[index]['mms'] == null
                                      ? Container()
                                      : Container(
                                          padding: list[index]['senderid'] == widget.uid
                                              ? EdgeInsets.only(bottom: hp(2.5), left: wp(15), right: wp(5))
                                              : EdgeInsets.only(bottom: hp(2.5), left: wp(5), right: wp(15)),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: CachedNetworkImage(
                                              imageUrl: list[index]['mms'],
                                              placeholder: (context, url) => CircularProgressIndicator(),
                                              errorWidget: (context, url, error) => Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                  // Message
                                  list[index]['message'] == null
                                      ? Container()
                                      : Container(
                                          padding: list[index]['senderid'] == widget.uid
                                              ? EdgeInsets.only(bottom: hp(2.5), left: wp(15), right: wp(5))
                                              : EdgeInsets.only(bottom: hp(2.5), left: wp(5), right: wp(15)),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: list[index]['senderid'] == widget.uid
                                                  ? Colors.black12
                                                  : Colors.black87,
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(25),
                                                topRight: const Radius.circular(25),
                                                bottomLeft: const Radius.circular(25),
                                                bottomRight: const Radius.circular(25),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  top: hp(1.5), bottom: hp(1.5), left: wp(3), right: wp(3)),
                                              child: Text(
                                                list[index]['message'],
                                                style: TextStyle(
                                                  color: list[index]['senderid'] == widget.uid
                                                      ? Colors.black87
                                                      : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                ],
                              );
                            },
                          )
                        : Center(
                            child: Text('Send the first message!'),
                          );
                }
              },
            ),
          ),
          // TextField here --------------------------------------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: Colors.white54,
              boxShadow: [
                BoxShadow(
                  color: Colors.white54,
                  blurRadius: 10,
                  spreadRadius: 5,
                  offset: Offset(0, 1),
                  // Code cleanup: Can possibly remove offset value
                )
              ],
            ),
            child: TextField(
              // onTap: () {
              // When the user presses the send button, check if the user has selected an image.
              // If not, open the keyboard, prompting the user to type.
              // _file != null ? _focus.unfocus() : _focus.requestFocus();
              // The reason I cannot have this here is due to the fact that every button registers as the TextField.
              // FIX: Have buttons next to the TextField in a row f.ex, instead of having buttons as suffix icons- ect.
              // WHEN YOU DO THIS, CLEAN UP THE CODE AND REMOVE THE FOCUS NODE - NULL.
              // },
              focusNode: _focus,
              cursorColor: Colors.black87,
              cursorWidth: 1,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              controller: msgController,
              style: TextStyle(
                fontSize: wp(4),
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    MaterialButton(
                      elevation: 0,
                      highlightElevation: 0,
                      minWidth: 0,
                      padding: EdgeInsets.all(0),
                      onPressed: () {
                        chooseMMS(false);
                      },
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      shape: CircleBorder(),
                      child: Opacity(
                        opacity: 0.75,
                        child: Icon(
                          Icons.image,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _file == null ? wp(0) : null,
                      height: _file == null ? hp(0) : null,
                      child: Padding(
                        padding: EdgeInsets.only(right: wp(2.5), top: hp(1), bottom: hp(1)),
                        child: _file == null
                            ? Container()
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  height: wp(5),
                                  width: wp(5),
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: Image.file(_file),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                suffixIcon: MaterialButton(
                  elevation: 0,
                  highlightElevation: 0,
                  minWidth: 0,
                  padding: EdgeInsets.all(0),
                  onPressed: () {
                    msgController.text = msgController.text.trim();
                    if (_file == null && msgController.text.isEmpty || msgController.text == ' ') {
                      // Possibility: Prompting the user for text in some way.
                    } else {
                      sendMsg();
                    }
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  shape: CircleBorder(),
                  child: Opacity(
                    // opacity: msgController.text.isEmpty ? 0.25 : 1,
                    opacity: 0.75,
                    child: Icon(
                      Icons.send,
                      color: Colors.black87,
                    ),
                  ),
                ),
                contentPadding: EdgeInsets.only(top: hp(2.5), left: wp(5), right: wp(2.5)),
                fillColor: Colors.white54,
                filled: true,
                hintText: "Type a message...",
                hintStyle: TextStyle(
                  fontSize: wp(4),
                  color: Colors.black87,
                ),
                border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(const Radius.circular(100)),
                    borderSide: BorderSide(color: Colors.white54)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: Colors.white54)),
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: Colors.white54)),
              ),
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 500),
              height: isSending ? hp(0.2) : hp(0),
              width: wp(100),
              child: LinearProgressIndicator(
                backgroundColor: Colors.black87,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
