import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/gradient_background.dart'; // Add this import

class CartPage extends StatefulWidget {
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isOrderPlaced = false;

  Future<void> _updateCartItem(String userId, String itemId, int change) async {
    if (_isOrderPlaced) return;

    try {
      final docRef = _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .doc(itemId);

      if (change == -1) {
        final doc = await docRef.get();
        if (doc.exists && (doc.data()?['quantity'] ?? 0) <= 1) {
          await docRef.delete();
        } else {
          await docRef.update({'quantity': FieldValue.increment(change)});
        }
      } else {
        await docRef.update({'quantity': FieldValue.increment(change)});
      }
    } on FirebaseException catch (e) {
      debugPrint('Error updating cart: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<void> _processCheckout(String userId, List<QueryDocumentSnapshot> items, int total) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text('Are you sure you want to place this order for \$$total?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final orderId = _firestore.collection('orders').doc().id;
    final now = DateTime.now();
    final dateString = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';

    final orderData = {
      'orderId': orderId,
      'userId': userId,
      'total': total,
      'status': 'Processing',
      'date': dateString,
      'timestamp': FieldValue.serverTimestamp(),
      'items': items.map((item) {
        final data = item.data() as Map<String, dynamic>;
        return {
          'productId': item.id,
          'name': data['name'],
          'price': data['price'],
          'quantity': data['quantity'],
          'imageUrl': data['imageUrl'],
        };
      }).toList(),
    };

    try {
      await _firestore.runTransaction((transaction) async {
        transaction.set(
          _firestore.collection('orders').doc(orderId),
          orderData,
        );

        transaction.set(
          _firestore.collection('history').doc(orderId),
          {
            'userId': userId,
            'orderId': orderId,
            'action': 'Order placed',
            'message': 'You placed an order for \$$total',
            'timestamp': FieldValue.serverTimestamp(),
            'date': dateString,
          },
        );

        for (final item in items) {
          transaction.delete(
            _firestore.collection('carts').doc(userId).collection('items').doc(item.id),
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _isOrderPlaced = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, '/main');
      });
    } catch (e) {
      debugPrint('Error during checkout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to place order. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent, // Set transparent background
        body: buildGradientBackground( // Wrap with gradient background
          child: SafeArea(
            child: Column(
              children: [
                // Custom app bar for gradient background
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Your Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Please sign in to view your cart',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/auth', arguments: 0),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade900,
                          ),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Set transparent background
      body: buildGradientBackground( // Wrap with gradient background
        child: SafeArea(
          child: Column(
            children: [
              // Custom app bar for gradient background
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pushReplacementNamed(context, '/main'),
                    ),
                    const Text(
                      'Your Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('carts')
                      .doc(user.uid)
                      .collection('items')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Error loading cart',
                              style: TextStyle(color: Colors.white),
                            ),
                            if (snapshot.error is FirebaseException)
                              ElevatedButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/auth',
                                  arguments: 0,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue.shade900,
                                ),
                                child: const Text('Sign In Again'),
                              ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }

                    final items = snapshot.data?.docs ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Your cart is empty',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }

                    int total = items.fold(0, (sum, doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return sum + (data['price'] as int) * (data['quantity'] as int);
                    });

                    return Column(
                      children: [
                        Flexible(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final data = item.data() as Map<String, dynamic>;
                              return Opacity(
                                opacity: _isOrderPlaced ? 0.6 : 1.0,
                                child: Dismissible(
                                  key: Key(item.id),
                                  direction: _isOrderPlaced ? DismissDirection.none : DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) async {
                                    try {
                                      await _firestore
                                          .collection('carts')
                                          .doc(user.uid)
                                          .collection('items')
                                          .doc(item.id)
                                          .delete();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to remove item'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.asset(
                                          data['imageUrl'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      title: Text(
                                        data['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '\$${data['price']} each',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      trailing: Container(
                                        width: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: _isOrderPlaced
                                                  ? null
                                                  : () => _updateCartItem(user.uid, item.id, -1),
                                            ),
                                            Text(
                                              '${data['quantity']}',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: _isOrderPlaced
                                                  ? null
                                                  : () => _updateCartItem(user.uid, item.id, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$$total',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _isOrderPlaced
                                    ? null
                                    : () => _processCheckout(user.uid, items, total),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: Colors.deepOrange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _isOrderPlaced ? 'Order Placed' : 'Checkout (\$$total)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}