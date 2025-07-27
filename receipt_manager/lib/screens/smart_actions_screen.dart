import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SmartActionsScreen extends StatefulWidget {
  final String receiptId;
  final String userId;

  const SmartActionsScreen({
    super.key,
    required this.receiptId,
    required this.userId,
  });

  @override
  State<SmartActionsScreen> createState() => _SmartActionsScreenState();
}

class _SmartActionsScreenState extends State<SmartActionsScreen> {
  bool isLoading = true;
  Map<String, dynamic> smartActions = {};
  List<String> selectedActions = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSmartActions();
  }

  Future<void> _fetchSmartActions() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.32.150:8000/smart-actions?receipt_id=${widget.receiptId}&user_id=${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          smartActions = data['smartactions'] ?? {};
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load smart actions';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _toggleAction(String actionKey) {
    setState(() {
      if (selectedActions.contains(actionKey)) {
        selectedActions.remove(actionKey);
      } else {
        selectedActions.add(actionKey);
      }
    });
  }

  Color _getActionColor(String actionKey) {
    final colors = {
      'auto_split_receipt': Colors.blue,
      'detect_similar_purchases': Colors.green,
      'export_format': Colors.orange,
      'generate_invoice_pdf': Colors.purple,
      'receipt_expiry': Colors.grey,
      'savings_pot': Colors.teal,
      'preferred_language': Colors.indigo,
    };
    return colors[actionKey] ?? Colors.blueGrey;
  }

  IconData _getActionIcon(String actionKey) {
    final icons = {
      'auto_split_receipt': Icons.group,
      'detect_similar_purchases': Icons.search,
      'export_format': Icons.download,
      'generate_invoice_pdf': Icons.picture_as_pdf,
      'receipt_expiry': Icons.schedule,
      'savings_pot': Icons.savings,
      'preferred_language': Icons.language,
    };
    return icons[actionKey] ?? Icons.lightbulb;
  }

  String _formatActionTitle(String actionKey) {
    return actionKey
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Smart Actions", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigoAccent),
                  SizedBox(height: 16),
                  Text("Generating smart suggestions...", style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(errorMessage!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          _fetchSmartActions();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                            const SizedBox(height: 12),
                            const Text(
                              "Smart Actions Available",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Select the actions you'd like to perform based on your preferences",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Smart Actions Grid
                      if (smartActions.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                "No smart actions available",
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Configure your preferences to see personalized suggestions",
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: smartActions.length,
                          itemBuilder: (context, index) {
                            final actionKey = smartActions.keys.elementAt(index);
                            final actionData = smartActions[actionKey];
                            final isSelected = selectedActions.contains(actionKey);
                            final actionColor = _getActionColor(actionKey);

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? actionColor.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? actionColor : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () => _toggleAction(actionKey),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header with icon and checkbox
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: actionColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getActionIcon(actionKey),
                                              color: actionColor,
                                              size: 24,
                                            ),
                                          ),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected ? actionColor : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected ? actionColor : Colors.grey[400]!,
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                                : null,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Title
                                      Text(
                                        _formatActionTitle(actionKey),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Question/Description
                                      Expanded(
                                        child: Text(
                                          actionData['question'] ?? 'No description available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            height: 1.3,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                      // Value/Currency if available
                                      if (actionData['value'] != null || actionData['currency'] != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: actionColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${actionData['currency'] ?? ''}${actionData['value'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: actionColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Skip", style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: selectedActions.isEmpty
                                  ? null
                                  : () {
                                      // TODO: Process selected actions
                                      _processSelectedActions();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                selectedActions.isEmpty
                                    ? "Select Actions"
                                    : "Execute ${selectedActions.length} Action${selectedActions.length > 1 ? 's' : ''}",
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  void _processSelectedActions() {
    // Show success message for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Actions Selected"),
        content: Text("Selected ${selectedActions.length} actions:\n${selectedActions.join(', ')}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}