import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/downtime_interval.dart';
import 'package:smart_sheet/widgets/session_card.dart';

class ActiveSessionsDashboard extends StatelessWidget {
  final Function(LiveSession) onFinishSession;
  final Function(LiveSession) onCancelSession; // ✅ إضافة دالة الإلغاء

  const ActiveSessionsDashboard({
    super.key,
    required this.onFinishSession,
    required this.onCancelSession, // ✅ تمرير الدالة للمُنشئ
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<LiveSession>('flexo_live_sessions').listenable(),
      builder: (context, Box<LiveSession> box, _) {
        if (box.isEmpty) {
          return const SizedBox.shrink();
        }

        final sessions = box.values.toList().reversed.toList();

        return Container(
          height: 280,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'الجلسات النشطة حالياً',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return SessionCard(
                      session: session,
                      onFinish: () => onFinishSession(session),
                      onCancel: () => onCancelSession(session), // ✅ تمرير الدالة للبطاقة
                      onToggleDowntime: (shouldResume) => _toggleDowntime(session, shouldResume),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleDowntime(LiveSession session, bool shouldResume) {
    if (shouldResume) {
      // End the last downtime interval
      if (session.downtimeIntervals.isNotEmpty) {
        final last = session.downtimeIntervals.last;
        last.end ??= DateTime.now();
      }
      session.isRunning = true;
    } else {
      // Start a new downtime interval
      session.downtimeIntervals.add(DowntimeInterval(start: DateTime.now()));
      session.isRunning = false;
    }
    session.lastStateChange = DateTime.now();
    session.save();
  }
}
