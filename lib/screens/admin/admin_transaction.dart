import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTransactionScreen extends StatelessWidget {
  const AdminTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ประวัติธุรกรรมการเงิน")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('wallet_transactions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              bool isIncome =
                  data['type'] == 'topup' || data['type'] == 'income';

              return ListTile(
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                ),
                title: Text("${data['type']} - User: ${data['member_id']}"),
                trailing: Text(
                  "${isIncome ? '+' : '-'}${data['amount']} ฿",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                subtitle: Text(data['createdAt']?.toDate().toString() ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
