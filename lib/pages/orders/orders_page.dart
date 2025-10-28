import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/order_service.dart';
import '../../models/order_status.dart';
import '../../widgets/order_card.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  late TabController _tabController;

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

  bool _isScheduledOrder(OrderStatus status) {
    return status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.pickupComplete;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2ECC71),
          tabs: const [Tab(text: 'SCHEDULED'), Tab(text: 'HISTORY')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(showScheduled: true),
          _buildOrdersList(showScheduled: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList({bool showScheduled = true}) {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _orderService.getUserOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        final filteredOrders =
            orders.where((doc) {
              final status = OrderStatus.fromString(doc['status']);
              return showScheduled
                  ? _isScheduledOrder(status)
                  : !_isScheduledOrder(status);
            }).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Text(
              showScheduled ? 'No scheduled orders' : 'No order history',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final doc = filteredOrders[index];
            final data = doc.data() as Map<String, dynamic>;
            return OrderCard(
              doc: doc,
              data: data,
              showScheduled: showScheduled,
            );
          },
        );
      },
    );
  }
}
