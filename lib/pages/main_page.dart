import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/gradient_background.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _cartItemCount = 0;
  StreamSubscription? _cartSubscription;

  // Store GlobalKeys for each product to maintain reference
  late List<GlobalKey> _productKeys;

  final List<Map<String, dynamic>> products = [
    {
      'id': '1',
      'imageUrl': 'assets/images/tahong1.jpg',
      'name': 'Tahong Fresh 1',
      'price': 10,
    },
    {
      'id': '2',
      'imageUrl': 'assets/images/tahong2.jpg',
      'name': 'Tahong Fresh 2',
      'price': 20,
    },
    {
      'id': '3',
      'imageUrl': 'assets/images/tahong3.jpg',
      'name': 'Tahong Fresh 3',
      'price': 15,
    },
    {
      'id': '4',
      'imageUrl': 'assets/images/tahong4.jpg',
      'name': 'Tahong Fresh 4',
      'price': 25,
    },
    {
      'id': '5',
      'imageUrl': 'assets/images/tahong1.jpg',
      'name': 'Tahong Fresh 5',
      'price': 30,
    },
    {
      'id': '6',
      'imageUrl': 'assets/images/tahong2.jpg',
      'name': 'Tahong Fresh 6',
      'price': 18,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize GlobalKeys for each product
    _productKeys = List.generate(products.length, (index) => GlobalKey());
    _setupCartListener();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    super.dispose();
  }

  void _setupCartListener() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('Setting up cart listener for user: ${user.uid}');
        _cartSubscription = _firestore
            .collection('carts')
            .doc(user.uid)
            .collection('items')
            .snapshots()
            .listen(
              (snapshot) {
                int totalItems = 0;
                for (var doc in snapshot.docs) {
                  totalItems += (doc.data()['quantity'] as int? ?? 0);
                }
                if (mounted) {
                  setState(() {
                    _cartItemCount = totalItems;
                  });
                }
                debugPrint('Cart item count updated: $_cartItemCount');
              },
              onError: (error) {
                debugPrint('Cart listener error: $error');
              },
            );
      }
    } catch (e) {
      debugPrint('Error setting up cart listener: $e');
    }
  }

  Future<void> _addToCart(
    Map<String, dynamic> product,
    int productIndex,
  ) async {
    debugPrint('Adding to cart: ${product['name']}');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to add items to cart'),
            ),
          );
          Navigator.pushNamed(context, '/auth', arguments: 0);
        }
        return;
      }

      debugPrint('User authenticated: ${user.uid}');

      // Play animation first (non-blocking)
      if (mounted && productIndex < _productKeys.length) {
        try {
          _playAddToCartAnimation(product, _productKeys[productIndex]);
        } catch (animationError) {
          debugPrint('Animation error (non-critical): $animationError');
        }
      }

      // Update cart in Firestore
      await _updateCartInFirestore(user, product);
      debugPrint('Cart updated successfully in Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product['name']} added to cart')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error adding to cart: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        String errorMessage = _getErrorMessage(e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _playAddToCartAnimation(
    Map<String, dynamic> product,
    GlobalKey productKey,
  ) async {
    try {
      final context = productKey.currentContext;
      if (context == null) {
        debugPrint('Product context is null, skipping animation');
        return;
      }

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) {
        debugPrint('RenderBox is null or has no size, skipping animation');
        return;
      }

      final position = renderBox.localToGlobal(Offset.zero);
      final screenSize = MediaQuery.of(this.context).size;

      // Calculate cart position (bottom navigation cart icon)
      final cartPosition = Offset(
        screenSize.width * 0.12, // Approximate cart icon position
        screenSize.height - 80, // Bottom navigation height
      );

      final controller = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      final positionAnimation = Tween<Offset>(
        begin: position,
        end: cartPosition,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      final scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 0.3,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      final opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: const Interval(0.7, 1.0)),
      );

      final overlayState = Overlay.of(this.context);
      OverlayEntry? overlayEntry;

      overlayEntry = OverlayEntry(
        builder:
            (context) => AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return Positioned(
                  left: positionAnimation.value.dx,
                  top: positionAnimation.value.dy,
                  child: Transform.scale(
                    scale: scaleAnimation.value,
                    child: Opacity(
                      opacity: opacityAnimation.value,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.deepOrange,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              product['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.shopping_cart,
                                    size: 30,
                                    color: Colors.deepOrange,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      );

      overlayState.insert(overlayEntry);

      await controller.forward();

      overlayEntry.remove();
      controller.dispose();

      debugPrint('Animation completed successfully');
    } catch (e) {
      debugPrint('Animation error: $e');
      // Don't rethrow - animation is optional
    }
  }

  // Simple approach without transactions - more reliable for Flutter Web
  Future<void> _updateCartInFirestore(
    User user,
    Map<String, dynamic> product,
  ) async {
    debugPrint(
      'Updating cart in Firestore for user: ${user.uid}, product: ${product['id']}',
    );

    final userCartRef = _firestore.collection('carts').doc(user.uid);
    final itemRef = userCartRef.collection('items').doc(product['id']);

    try {
      // Ensure cart document exists first
      await userCartRef.set(
        {'createdAt': FieldValue.serverTimestamp(), 'userId': user.uid},
        SetOptions(merge: true),
      ); // merge: true prevents overwriting existing data

      debugPrint('Cart document created/updated');

      // Check if item exists and update accordingly
      final itemDoc = await itemRef.get();

      if (itemDoc.exists) {
        debugPrint('Updating existing item quantity');
        final currentQuantity = itemDoc.data()?['quantity'] as int? ?? 0;
        await itemRef.update({
          'quantity': currentQuantity + 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        debugPrint('Creating new item document');
        await itemRef.set({
          'name': product['name'],
          'price': product['price'],
          'imageUrl': product['imageUrl'],
          'quantity': 1,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Cart update completed successfully');
    } catch (e, stackTrace) {
      debugPrint('Error in _updateCartInFirestore: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Helper method to get user-friendly error messages
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      debugPrint('Firebase error code: ${error.code}');
      debugPrint('Firebase error message: ${error.message}');

      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Please check your account access.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        case 'unauthenticated':
          return 'Authentication required. Please sign in again.';
        case 'deadline-exceeded':
          return 'Request timed out. Please check your connection.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait a moment.';
        default:
          return 'Error: ${error.message ?? "Unknown Firebase error"}';
      }
    }

    // Handle network errors
    if (error.toString().contains('network') ||
        error.toString().contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }

    return 'Failed to add item to cart. Please try again.';
  }

  Widget productCard({
    required String imageUrl,
    required String name,
    required int price,
    required String id,
    required GlobalKey key,
    required int index,
  }) {
    return Card(
      key: key,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 40),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blueGrey.shade900,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '\$${price}', // This will display the actual price value like "$10", "$20", etc.
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton.icon(
                onPressed:
                    () => _addToCart({
                      'id': id,
                      'imageUrl': imageUrl,
                      'name': name,
                      'price': price,
                    }, index),
                icon: const Icon(
                  Icons.add_shopping_cart,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: buildGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Local Tahong Market',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                    children:
                        products.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> product = entry.value;
                          return productCard(
                            key: _productKeys[index],
                            imageUrl: product['imageUrl'],
                            name: product['name'],
                            price: product['price'],
                            id: product['id'],
                            index: index,
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.blue.shade900,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (_cartItemCount > 0)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_cartItemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/cart');
              break;
            case 1:
              Navigator.pushNamed(context, '/history');
              break;
            case 2:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }
}
