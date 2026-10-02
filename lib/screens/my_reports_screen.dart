import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../demo/demo.dart';
import '../services/support_service.dart';
import '../theme/app_colors.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.warmPageBackground,
    appBar: AppBar(title: const Text('My reports & replies')),
    body: Demo.on ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Demo reports are simulated. An administrator is not connected to this demo.')))
      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: SupportService.mySubmissions(),
        builder: (context, submissions) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SupportService.myReplies(),
          builder: (context, replies) {
            if (submissions.hasError || replies.hasError) return const Center(child: Text('Could not load your reports. Check your connection and try again.'));
            if (!submissions.hasData || !replies.hasData) return const Center(child: CircularProgressIndicator());
            final docs = submissions.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('No reports or partnership inquiries yet.'));
            return ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Your newest 50 submissions. Replies appear here; internal admin notes stay private.'),
              const SizedBox(height: 12),
              for (final doc in docs) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.data()['title'] as String? ?? 'Support request', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(switch (doc.data()['status']) { 'resolved' => 'Resolved', 'in_progress' => 'In progress', _ => 'Submitted' }),
                  if ((doc.data()['body'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(doc.data()['body'] as String)),
                  for (final reply in replies.data!.docs.where((r) => r.data()['source_id'] == doc.id && r.data()['source_collection'] == doc.data()['source_collection']).toList().reversed) ...[
                    const Divider(height: 24),
                    const Text('Rakta Bandhan support', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(reply.data()['body'] as String? ?? ''),
                  ],
                ],
              ))),
            ]);
          },
        ),
      ),
  );
}
