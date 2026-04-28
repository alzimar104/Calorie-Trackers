import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String isim = "";
  int kilo = 0;
  int boy = 0;
  String profilFotoUrl = "";

  TextEditingController isimController = TextEditingController();
  TextEditingController kiloController = TextEditingController();
  TextEditingController boyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        isim = data['isim'] ?? "";
        kilo = data['kilo'] ?? 0;
        boy = data['boy'] ?? 0;
        profilFotoUrl = data['profilFotoUrl'] ?? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(data['isim'] ?? 'User')}&background=random";

        isimController.text = isim;
        kiloController.text = kilo.toString();
        boyController.text = boy.toString();
      });
    }
  }

  Future<void> _updateUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newIsim = isimController.text;
    final newKilo = int.tryParse(kiloController.text) ?? kilo;
    final newBoy = int.tryParse(boyController.text) ?? boy;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'isim': newIsim,
      'kilo': newKilo,
      'boy': newBoy,
      'profilFotoUrl': profilFotoUrl,
    }, SetOptions(merge: true));

    setState(() {
      isim = newIsim;
      kilo = newKilo;
      boy = newBoy;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bilgiler güncellendi!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Bilgileri')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                child: profilFotoUrl.isEmpty
                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                  : ClipOval(
                      child: Image.network(
                        profilFotoUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.person, size: 50, color: Colors.grey[400]);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: isimController,
              decoration: InputDecoration(labelText: 'İsim', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: boyController,
                    decoration: InputDecoration(labelText: 'Boy (cm)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: kiloController,
                    decoration: InputDecoration(labelText: 'Kilo (kg)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateUserData,
              child: Text('Bilgileri Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
