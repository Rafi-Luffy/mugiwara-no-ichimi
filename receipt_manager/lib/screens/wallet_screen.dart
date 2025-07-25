// Updated WalletScreen with proper container and navigation
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/image_picker_modal.dart';
import '../widgets/wallet_card.dart';
import '../widgets/preference_onboarding_screen.dart';
import 'wallet_pass_detail_screen.dart'; 
import 'luffy_chatbot_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ImagePickerModal(),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Wrap(children: const [
        ListTile(leading: Icon(Icons.analytics), title: Text('Analytics')),
        ListTile(leading: Icon(Icons.folder), title: Text('Folders')),
        ListTile(leading: Icon(Icons.star), title: Text('Rewards')),
      ]),
    );
  }

  static Future<User?> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      print('Google Sign-In Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In failed')),
      );
      return null;
    }
  }

  void _showPreferenceSetup(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final user = await _signInWithGoogle(context);
    Navigator.of(context).pop(); // Remove loading dialog

    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreferenceOnboardingScreen(
            userId: user.uid,
            userName: user.displayName ?? 'User',
            userEmail: user.email ?? '',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed')),
      );
    }
  }

  void _navigateToWalletDetail(String documentId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalletPassDetailScreen(
          documentId: documentId,
          passData: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userInitial = user?.displayName?.substring(0, 1).toUpperCase() ?? 'K';

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Wallet",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () => _showPreferenceSetup(context),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        child: Text(
                          userInitial,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hardcoded passes
                // GestureDetector(
                //   onTap: () => _navigateToWalletDetail('hardcoded_1', {
                //     'shop_name': 'test',
                //     'shop_location': 'hackathon venue',
                //     'total_amount': '0',
                //     'expense_category': 'Others',
                //     'date': 'Demo',
                //     'items': [],
                //   }),
                //   child: const WalletCard(
                //       title: "test", subtitle: "hackathon", color: Colors.blue),
                // ),
                // GestureDetector(
                //   onTap: () => _navigateToWalletDetail('hardcoded_2', {
                //     'shop_name': 'PVR',
                //     'shop_location': 'Cinema Complex',
                //     'total_amount': '5000',
                //     'expense_category': 'Entertainment',
                //     'date': 'Gift Card',
                //     'items': [],
                //   }),
                //   child: const WalletCard(
                //       title: "PVR",
                //       subtitle: "Gift card: ₹5,000",
                //       color: Colors.orange),
                // ),

                // Container for Firestore Wallet Passes
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 100), // Space for bottom buttons
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: user != null 
                          ? FirebaseFirestore.instance
                              .collection('wallet_passes')
                              .where('user_id', isEqualTo: user.uid)
                              .snapshots() // Removed orderBy to avoid index requirement
                          : null,
                      builder: (context, snapshot) {
                        if (user == null) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text("Please sign in to view wallet passes."),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                "Error loading wallet passes: ${snapshot.error}",
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wallet, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    "No wallet passes yet.",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Add your first receipt to get started!",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Sort documents by timestamp on client side
                        final docs = snapshot.data!.docs;
                        docs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aTimestamp = aData['timestamp'] as Timestamp?;
                          final bTimestamp = bData['timestamp'] as Timestamp?;
                          
                          if (aTimestamp == null && bTimestamp == null) return 0;
                          if (aTimestamp == null) return 1;
                          if (bTimestamp == null) return -1;
                          
                          return bTimestamp.compareTo(aTimestamp); // Descending order
                        });

                        return ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: GestureDetector(
                                onTap: () => _navigateToWalletDetail(doc.id, data),
                                child: WalletCard(
                                  title: data['shop_name'] ?? 'Shop',
                                  subtitle: "₹${data['total_amount'] ?? '0'} • ${data['expense_category'] ?? 'Uncategorized'}",
                                  color: _getCategoryColor(data['expense_category']),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                const Center(
                  child: Text("Archived passes",
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),

          // Bottom action bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Luffy agent
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Text(
                          "Luffy's on Deck!",
                          style:
                              TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ),
                      CustomPaint(
                        size: const Size(12, 6),
                        painter:
                            BubbleTailPainterUpward(color: Color(0xFFE3F2FD)),
                      ),
                      GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LuffyChatbotScreen(),
      ),
    );
  },
  child: const CircleAvatar(
    backgroundColor: Colors.white,
    radius: 24,
    backgroundImage: AssetImage('assets/images/luffy_agent.png'),
  ),
),
                      // GestureDetector(
                      //   // onTap: () => _showPreferenceSetup(context),
                      //   child: const CircleAvatar(
                      //     backgroundColor: Colors.white,
                      //     radius: 24,
                      //     backgroundImage:
                      //         AssetImage('assets/images/luffy_agent.png'),
                      //   ),
                      // ),
                    ],
                  ),

                  // Add to Wallet Button
                  FloatingActionButton.extended(
                    onPressed: () => _showImagePicker(context),
                    icon: const Icon(Icons.add),
                    label: const Text("Add to Wallet"),
                  ),

                  // More options
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 30),
                    onPressed: () => _showMoreOptions(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'groceries':
        return Colors.green;
      case 'travel':
        return Colors.blue;
      case 'entertainment':
        return Colors.purple;
      case 'food':
        return Colors.orange;
      default:
        return const Color.fromARGB(255, 134, 150, 240);
    }
  }
}

class BubbleTailPainterUpward extends CustomPainter {
  final Color color;

  BubbleTailPainterUpward({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}