import 'package:add_to_google_wallet/widgets/add_to_google_wallet_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'smart_actions_screen.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String receipt_id;

  const ReceiptDetailsScreen({
    Key? key,
    required this.data,
    required this.receipt_id,
  }) : super(key: key);

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  bool showAllItems = false;
  bool reimbursable = false;
  final notesController = TextEditingController();
  final String passId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    reimbursable = widget.data['reimbursable_items']?.isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(widget.data['items'] ?? []);
    final categories = ["Groceries", "Travel", "Entertainment", "Food", "Others"];
    final selectedCategory = widget.data['expense_category'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Receipt"),
        backgroundColor: Colors.indigoAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 📍 Shop Info
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.data['shop_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.data['shop_location'] ?? '', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {
                  // Optional: Launch Google Maps here
                },
              )
            ],
          ),
          const SizedBox(height: 16),

          // 💰 Total Card & Items
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFa1c4fd), Color(0xFFc2e9fb)]),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Spent: ₹${widget.data['total_amount'] ?? '0'}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...items.take(showAllItems ? items.length : 5).map((item) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(item['name'], overflow: TextOverflow.ellipsis)),
                      Text("₹${item['amount'] ?? ''}"),
                    ],
                  );
                }),
                if (items.length > 5)
                  TextButton(
                    onPressed: () => setState(() => showAllItems = !showAllItems),
                    child: Text(showAllItems ? "Hide Items" : "View Items"),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 🏷️ Categories
          const Text("Categories", style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              ...categories.map((cat) => ChoiceChip(
                    label: Text(cat),
                    selected: cat == selectedCategory,
                    onSelected: (_) {},
                  )),
              ActionChip(
                label: const Text("Add"),
                onPressed: () {
                  // Handle Add category
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 🔁 Reimbursable Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Reimbursable Expense", style: TextStyle(fontWeight: FontWeight.bold)),
              Switch(
                value: reimbursable,
                onChanged: (val) => setState(() => reimbursable = val),
              )
            ],
          ),

          const SizedBox(height: 16),

          // 📝 Notes
          const Text("Notes"),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Add a note for this receipt...",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 32),

          // 🧾 Add to Google Wallet
          Center(
            child: AddToGoogleWalletButton(
              pass: _buildWalletPass(widget.data),
              onError: (e) => _showSnackBar(context, "❌ Error: $e", Colors.red),
              onSuccess: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  _showSnackBar(context, "❌ User not signed in", Colors.red);
                  return;
                }

                try {
                  DocumentReference docRef = await FirebaseFirestore.instance.collection('wallet_passes').add({
                    'user_id': user.uid,
                    'shop_name': widget.data['shop_name'],
                    'shop_location': widget.data['shop_location'],
                    'total_amount': widget.data['total_amount'],
                    'expense_category': widget.data['expense_category'],
                    'date': widget.data['date'],
                    'items': widget.data['items'],
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  _showSnackBar(context, "✅ Pass added successfully", Colors.green);

                  await Future.delayed(const Duration(milliseconds: 1500));

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SmartActionsScreen(
                          receiptId: docRef.id,
                          userId: user.uid,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  _showSnackBar(context, "❌ Error saving: $e", Colors.red);
                }
              },
              onCanceled: () => _showSnackBar(context, "⚠️ Canceled", Colors.orange),
            ),
          ),

          const SizedBox(height: 16),

          // 👉 Preview Smart Actions button
          Center(
            child: TextButton.icon(
              onPressed: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SmartActionsScreen(
                        receiptId: widget.receipt_id,
                        userId: user.uid,
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Preview Smart Actions"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.indigoAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildWalletPass(Map<String, dynamic> data) {
    const String issuerId = '3388000000022955496';
    const String issuerEmail = 'keerthanajothiramesh@gmail.com';
    const String passClass = 'ShoppingList';

    return """
      {
        "iss": "$issuerEmail",
        "aud": "google",
        "typ": "savetowallet",
        "payload": {
          "genericObjects": [
            {
              "id": "$issuerId.$passId",
              "classId": "$issuerId.$passClass",
              "genericType": "GENERIC_TYPE_UNSPECIFIED",
              "hexBackgroundColor": "#0077B6",
              "logo": {
                "sourceUri": {
                  "uri": "https://storage.googleapis.com/wallet-lab-tools-codelab-artifacts-public/pass_google_logo.jpg"
                }
              },
              "cardTitle": {
                "defaultValue": {
                  "language": "en",
                  "value": "${data['shop_name'] ?? 'Receipt'}"
                }
              },
              "subheader": {
                "defaultValue": {
                  "language": "en",
                  "value": "${data['shop_location'] ?? ''}"
                }
              },
              "header": {
                "defaultValue": {
                  "language": "en",
                  "value": "₹${data['total_amount'] ?? '0'}"
                }
              },
              "barcode": {
                "type": "QR_CODE",
                "value": "$passId"
              },
              "textModulesData": [
                {
                  "header": "Expense Category",
                  "body": "${data['expense_category'] ?? 'Uncategorized'}",
                  "id": "category"
                }
              ]
            }
          ]
        }
      }
    """;
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
    ));
  }
}
