import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/gradient_background.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  String _selectedStatus = 'All';
  
  final List<String> _statusOptions = ['All', 'Processing', 'Preparing', 'Ready', 'Completed', 'Cancelled'];
  final Map<String, Color> _statusColors = {
    'Processing': Colors.orange,
    'Preparing': Colors.blue,
    'Ready': Colors.green,
    'Completed': Colors.grey,
    'Cancelled': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Update order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Add to history
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final now = DateTime.now();
        final dateString = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
        
        await _firestore.collection('history').doc().set({
          'userId': orderData['userId'],
          'orderId': orderId,
          'action': 'Status updated',
          'message': 'Your order status has been updated to $newStatus',
          'timestamp': FieldValue.serverTimestamp(),
          'date': dateString,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showOrderDetails(Map<String, dynamic> orderData) async {
    final items = orderData['items'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${orderData['orderId']?.substring(0, 8) ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer ID: ${orderData['userId']?.substring(0, 8) ?? 'N/A'}'),
              Text('Date: ${orderData['date'] ?? 'N/A'}'),
              Text('Status: ${orderData['status'] ?? 'N/A'}'),
              Text('Total: \$${orderData['total'] ?? 0}'),
              const SizedBox(height: 16),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${item['name']} x${item['quantity']} - \$${item['price']}'),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusUpdateDialog(String orderId, String currentStatus) async {
    String? newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Status: $currentStatus'),
            const SizedBox(height: 16),
            const Text('Select new status:'),
            const SizedBox(height: 8),
            ..._statusOptions.where((status) => status != 'All').map((status) => 
              ListTile(
                title: Text(status),
                leading: CircleAvatar(
                  backgroundColor: _statusColors[status] ?? Colors.grey,
                  radius: 8,
                ),
                onTap: () => Navigator.pop(context, status),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      await _updateOrderStatus(orderId, newStatus);
    }
  }

  Widget _buildOrdersList() {
    Query query = _firestore.collection('orders').orderBy('timestamp', descending: true);
    
    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
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

        final orders = snapshot.data?.docs ?? [];
        
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No orders found',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Processing';
            final items = data['items'] as List<dynamic>? ?? [];
            final itemCount = items.length;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with order ID and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${data['orderId']?.substring(0, 8) ?? 'N/A'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColors[status] ?? Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Order details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer: ${data['userId']?.substring(0, 8) ?? 'N/A'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${data['date'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Items: $itemCount item${itemCount != 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: \$${data['total'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showOrderDetails(data),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(80, 32),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showStatusUpdateDialog(order.id, status),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(80, 32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        final orders = snapshot.data!.docs;
        final Map<String, int> statusCounts = {};
        int totalRevenue = 0;

        for (var order in orders) {
          final data = order.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'Processing';
          final total = data['total'] ?? 0;
          
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
          if (status == 'Completed') {
            totalRevenue += total as int;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Revenue Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Revenue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$$totalRevenue',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Status Cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: _statusOptions.where((status) => status != 'All').map((status) {
                    final count = statusCounts[status] ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: _statusColors[status] ?? Colors.grey,
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: buildGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom app bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    ),
                  ],
                ),
              ),
              
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blue,
                  labelColor: Colors.blue.shade800,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: "Orders"),
                    Tab(text: "Statistics"),
                  ],
                ),
              ),
              
              // Filter dropdown for orders tab
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedStatus = newValue!;
                    });
                  },
                  items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          if (value != 'All') ...[
                            CircleAvatar(
                              backgroundColor: _statusColors[value] ?? Colors.grey,
                              radius: 8,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(value == 'All' ? 'All Orders' : value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrdersList(),
                    _buildOrderStats(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}