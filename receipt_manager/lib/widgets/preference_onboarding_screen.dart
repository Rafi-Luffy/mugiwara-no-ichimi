import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// class PreferenceOnboardingScreen extends StatefulWidget {
//   const PreferenceOnboardingScreen({super.key});

//   @override
//   State<PreferenceOnboardingScreen> createState() =>
//       _PreferenceOnboardingScreenState();
// }
class PreferenceOnboardingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  // final bool isFirstTime;

  const PreferenceOnboardingScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<PreferenceOnboardingScreen> createState() =>
      _PreferenceOnboardingScreenState();
}

class _PreferenceOnboardingScreenState
    extends State<PreferenceOnboardingScreen> with TickerProviderStateMixin {
  final CardSwiperController _controller = CardSwiperController();
  late AnimationController _luffyAnimationController;
  late Animation<double> _luffyBounceAnimation;
  late AnimationController _cardAnimationController;
  late Animation<double> _cardScaleAnimation;

  final List<Map<String, dynamic>> preferences = [
    {
      "key": "preferred_language",
      "title": "Choose your preferred language",
      "needsInput": true,
      "luffyMessage": "Yo! What language do you speak? I know many from my adventures!",
      "inputType": "dropdown"
    },
    {
      "key": "auto_split_receipt",
      "title": "Auto-split receipts above a certain amount?",
      "needsInput": true,
      "luffyMessage": "Should I help split the bill when it's really big? Like after a feast!",
      "inputType": "number"
    },
    {
      "key": "detect_similar_purchases",
      "title": "Detect similar purchases?",
      "needsInput": false,
      "luffyMessage": "Want me to spot when you buy the same stuff? I'm good at remembering food!",
      "inputType": "none"
    },
    {
      "key": "generate_invoice_pdf",
      "title": "Auto-generate and email PDF invoices?",
      "needsInput": true,
      "luffyMessage": "I can send you neat papers of your spending! What's your email?",
      "inputType": "email"
    },
    {
      "key": "export_format",
      "title": "Select your preferred export formats",
      "needsInput": true,
      "luffyMessage": "How do you want your treasure data? Pick your favorite formats!",
      "inputType": "multiselect"
    },
    {
      "key": "savings_pot",
      "title": "Save a fixed amount from each receipt?",
      "needsInput": true,
      "luffyMessage": "Want to save some berries from every purchase? Smart thinking!",
      "inputType": "number"
    },
    {
      "key": "notifications",
      "title": "Enable notifications for reminders and insights?",
      "needsInput": false,
      "luffyMessage": "Should I remind you about important money stuff? I'm great at that!",
      "inputType": "none"
    },
    {
      "key": "receipt_expiry",
      "title": "Auto-delete old receipts after some time?",
      "needsInput": true,
      "luffyMessage": "How long should I keep your old receipts? Don't worry, I won't forget!",
      "inputType": "dropdown"
    },
  ];

  Map<String, dynamic> acceptedPreferences = {};
  Map<String, dynamic> additionalInputs = {};

  int currentIndex = 0;
  bool allSwiped = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _luffyAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _luffyBounceAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _luffyAnimationController,
      curve: Curves.bounceInOut,
    ));

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    _luffyAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _luffyAnimationController.dispose();
    _cardAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSwipe(int index, CardSwiperDirection direction) async {
    final pref = preferences[index];
    final key = pref['key'];
    final accepted = direction == CardSwiperDirection.right;

    if (accepted && pref['needsInput']) {
      final value = await _showInputDialog(pref);
      if (value != null) {
        acceptedPreferences[key] = true;
        additionalInputs[key] = value;
      } else {
        return;
      }
    } else {
      acceptedPreferences[key] = accepted;
    }

    setState(() {
      currentIndex = index + 1;
    });

    if (index >= preferences.length - 1) {
      setState(() => allSwiped = true);
    }
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    _handleSwipe(previousIndex, direction);
    return true;
  }


  Future<dynamic> _showInputDialog(Map<String, dynamic> pref) async {
    final key = pref['key'];
    final inputType = pref['inputType'];
    final luffyMessage = pref['luffyMessage'];

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Luffy Avatar with message
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade300, Colors.red.shade300],
                      ),
                    ),
                    child: ClipOval(
                          child: Image.asset(
                            'assets/images/luffy_agent.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        luffyMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                pref['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildInputWidget(inputType, key),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, null),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Skip", style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () => _submitDialogInput(dialogContext, inputType, key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Confirm", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Controllers for different input types
  final TextEditingController _textController = TextEditingController();
  String? _selectedLanguage;
  String? _selectedExpiry;
  List<String> _selectedFormats = [];

  Widget _buildInputWidget(String inputType, String key) {
    switch (inputType) {
      case 'dropdown':
        if (key == 'preferred_language') {
          return _buildLanguageDropdown();
        } else if (key == 'receipt_expiry') {
          return _buildExpiryDropdown();
        }
        break;
      case 'multiselect':
        return _buildFormatMultiselect();
      case 'number':
      case 'email':
        return _buildTextField(inputType, key);
    }
    return Container();
  }

  Widget _buildLanguageDropdown() {
    final languages = [
      'English (Default)', 'Spanish', 'French', 'German', 'Italian',
      'Portuguese', 'Japanese', 'Korean', 'Chinese', 'Hindi', 'Arabic'
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          hint: const Text('Select Language'),
          isExpanded: true,
          items: languages.map((String language) {
            return DropdownMenuItem<String>(
              value: language,
              child: Text(language),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedLanguage = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildExpiryDropdown() {
    final expiryOptions = [
      '30 days', '60 days', '90 days', '6 months', '1 year', 'Never delete'
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExpiry,
          hint: const Text('Select Duration'),
          isExpanded: true,
          items: expiryOptions.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedExpiry = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFormatMultiselect() {
    final formats = ['PDF', 'Excel', 'JSON', 'CSV'];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        children: formats.map((format) {
          return CheckboxListTile(
            title: Text(format),
            value: _selectedFormats.contains(format),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedFormats.add(format);
                } else {
                  _selectedFormats.remove(format);
                }
              });
            },
            activeColor: Colors.blue.shade600,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField(String inputType, String key) {
    return TextField(
      controller: _textController,
      keyboardType: inputType == 'number' ? TextInputType.number : 
                   inputType == 'email' ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: _getHintText(key),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      autofocus: true,
    );
  }

  void _submitDialogInput(BuildContext dialogContext, String inputType, String key) {
    dynamic result;
    
    switch (inputType) {
      case 'dropdown':
        if (key == 'preferred_language') {
          result = _selectedLanguage;
        } else if (key == 'receipt_expiry') {
          result = _selectedExpiry;
        }
        break;
      case 'multiselect':
        result = _selectedFormats.isNotEmpty ? _selectedFormats : null;
        break;
      default:
        result = _textController.text.trim().isNotEmpty ? _textController.text.trim() : null;
    }
    
    // Reset controllers for next use
    _textController.clear();
    _selectedLanguage = null;
    _selectedExpiry = null;
    _selectedFormats = [];
    
    Navigator.pop(dialogContext, result);
  }

  String _getHintText(String key) {
    switch (key) {
      case 'auto_split_receipt':
        return 'Enter minimum amount (e.g., 50)';
      case 'generate_invoice_pdf':
        return 'Enter your email address';
      case 'savings_pot':
        return 'Enter amount to save (e.g., 5)';
      default:
        return 'Enter value';
    }
  }

  // Future<void> _submitPreferences() async {
  //   setState(() {
  //     isSubmitting = true;
  //   });

  //   final payload = <String, dynamic>{};
  //   for (var pref in preferences) {
  //     final key = pref['key'];
  //     payload[key] = acceptedPreferences[key] == true
  //         ? (additionalInputs.containsKey(key) 
  //             ? {"enabled": true, "value": additionalInputs[key]} 
  //             : true)
  //         : false;
  //   }

  //   try {
  //     // Replace with your actual backend URL
  //     final response = await http.post(
  //       Uri.parse('http://192.168.29.45:8000/user-preferences'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: json.encode(payload),
  //     );

  //     if (response.statusCode == 200) {
  //       // Success
  //       Navigator.pop(context, payload);
  //     } else {
  //       // Handle error
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to save preferences')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error: $e')),
  //     );
  //   } finally {
  //     setState(() {
  //       isSubmitting = false;
  //     });
  //   }
  // }

  Future<void> _submitPreferences() async {
  setState(() {
    isSubmitting = true;
  });

  // Build preferences payload according to Pydantic model
  final preferencesData = <String, dynamic>{};
  for (var pref in preferences) {
    final key = pref['key'];
    final isAccepted = acceptedPreferences[key] == true;
    
    if (isAccepted && additionalInputs.containsKey(key)) {
      // Preference with additional input value
      preferencesData[key] = {
        "enabled": true,
        "value": additionalInputs[key]
      };
    } else {
      // Simple boolean preference
      preferencesData[key] = isAccepted;
    }
  }

  // Create the complete payload matching PreferencesPayload model
  final payload = {
    "user_id": widget.userId,
    "user_name": widget.userName,
    "user_email": widget.userEmail,
    "preferences": preferencesData
  };

  try {
    // Send to your FastAPI backend
    final response = await http.post(
      Uri.parse('http://192.168.29.45:8000/user-preferences'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      // Parse the response
      final responseData = json.decode(response.body);
      
      // Optional: Also save to Firestore if you want dual storage
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
            'user_name': widget.userName,
            'user_email': widget.userEmail,
            'preferences': preferencesData,
            'preferences_id': responseData['preferences_id'],
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Navigate back with success
      Navigator.pop(context, preferencesData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hey, ${widget.userName}, you have successfully registered!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Handle HTTP error
      final errorData = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save preferences: ${errorData['detail'] ?? 'Unknown error'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Network error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      isSubmitting = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: currentIndex > 0 || allSwiped
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: allSwiped 
                    ? () => setState(() => allSwiped = false)
                    : () {
                        setState(() {
                          currentIndex = currentIndex > 0 ? currentIndex - 1 : 0;
                          allSwiped = false;
                        });
                      },
              )
            : null,
        title: Text(
          allSwiped 
              ? 'Review Preferences' 
              : 'Setup ${currentIndex + 1} of ${preferences.length}',
          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: allSwiped
            ? _buildReviewScreen()
            : _buildSwiperScreen(),
      ),
    );
  }

  Widget _buildReviewScreen() {
    return Column(
      children: [
        // Luffy congratulations
        AnimatedBuilder(
          animation: _luffyBounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _luffyBounceAnimation.value),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade100, Colors.red.shade100],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade300, Colors.red.shade300],
                        ),
                      ),
                      // child: const Icon(
                      //   Icons.sentiment_very_satisfied,
                      //   color: Colors.white,
                      //   size: 24,
                      // ),
                      child: ClipOval(
                          child: Image.asset(
                            'assets/images/luffy_agent.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Great job! Let's review your treasure map of preferences!",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: preferences.map((pref) {
              final key = pref['key'];
              final enabled = acceptedPreferences[key] == true;
              final hasValue = additionalInputs.containsKey(key);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade50,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    pref['title'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: hasValue 
                      ? Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Value: ${additionalInputs[key]}',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        )
                      : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: enabled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: enabled ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      enabled ? "Enabled" : "Disabled",
                      style: TextStyle(
                        color: enabled ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : _submitPreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      "Save My Preferences",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwiperScreen() {
    return Column(
      children: [
        // Luffy instruction
        AnimatedBuilder(
          animation: _luffyBounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _luffyBounceAnimation.value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade100, Colors.red.shade100],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade300, Colors.red.shade300],
                        ),
                      ),
                      child: ClipOval(
                          child: Image.asset(
                            'assets/images/luffy_agent.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Swipe right to enable, left to disable!",
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Swiper
        Expanded(
          child: CardSwiper(
            controller: _controller,
            cardsCount: preferences.length,
            onSwipe: _onSwipe,
            numberOfCardsDisplayed: 2,
            backCardOffset: const Offset(40, 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            cardBuilder: (context, index, horizontalThresholdPercentage, verticalThresholdPercentage) {
              final pref = preferences[index];
              return AnimatedBuilder(
                animation: _cardScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: index == 0 ? _cardScaleAnimation.value : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.blue.shade50,
                            Colors.white,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100,
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                                ),
                              ),
                              child: Icon(
                                _getIconForPreference(pref['key']),
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              pref['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (pref['needsInput']) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "📝 Additional input required",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton.extended(
                heroTag: "reject",
                onPressed: () {
                  _cardAnimationController.forward().then((_) {
                    _cardAnimationController.reverse();
                  });
                  _controller.swipe(CardSwiperDirection.left);
                },
                backgroundColor: Colors.red.shade500,
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text("Disable", style: TextStyle(color: Colors.white)),
              ),
              FloatingActionButton.extended(
                heroTag: "accept",
                onPressed: () {
                  _cardAnimationController.forward().then((_) {
                    _cardAnimationController.reverse();
                  });
                  _controller.swipe(CardSwiperDirection.right);
                },
                backgroundColor: Colors.green.shade500,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text("Enable", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForPreference(String key) {
    switch (key) {
      case 'preferred_language':
        return Icons.language;
      case 'auto_split_receipt':
        return Icons.receipt_long;
      case 'detect_similar_purchases':
        return Icons.analytics;
      case 'generate_invoice_pdf':
        return Icons.picture_as_pdf;
      case 'export_format':
        return Icons.file_download;
      case 'savings_pot':
        return Icons.savings;
      case 'notifications':
        return Icons.notifications;
      case 'receipt_expiry':
        return Icons.schedule;
      default:
        return Icons.settings;
    }
  }
}