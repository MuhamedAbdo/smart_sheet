import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_sheet/models/live_session.dart';

class SessionCard extends StatefulWidget {
  final LiveSession session;
  final VoidCallback onFinish;
  final Function(bool) onToggleDowntime;

  const SessionCard({
    super.key,
    required this.session,
    required this.onFinish,
    required this.onToggleDowntime,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  late Timer _timer;
  late Duration _displayDuration;

  @override
  void initState() {
    super.initState();
    _displayDuration = widget.session.netRunningTime;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _displayDuration = widget.session.netRunningTime;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaused = !widget.session.isRunning;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isPaused ? Colors.orange : Colors.green,
          width: 2,
        ),
      ),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.session.machineName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaused ? 'عطل' : 'يعمل',
                      style: TextStyle(
                        color: isPaused ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow(Icons.person, widget.session.clientName),
              _buildInfoRow(
                  Icons.numbers, "أمر: ${widget.session.orderNumber}"),
              InkWell(
                onTap: _selectStartTime,
                child: _buildInfoRow(
                  Icons.access_time,
                  "وقت البدء: ${widget.session.startTime.hour.toString().padLeft(2, '0')}:${widget.session.startTime.minute.toString().padLeft(2, '0')}",
                  isEditable: true,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _formatDuration(_displayDuration),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPaused ? Colors.green : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => widget.onToggleDowntime(isPaused),
                      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                      label: Text(isPaused ? 'تم الإصلاح' : 'تسجيل عطل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: widget.onFinish,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('إنهاء'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.session.startTime),
    );
    if (!mounted) return;
    if (picked != null) {
      final now = DateTime.now();
      final newStartTime = DateTime(
        widget.session.startTime.year,
        widget.session.startTime.month,
        widget.session.startTime.day,
        picked.hour,
        picked.minute,
      );

      // Don't allow start time in the future
      if (newStartTime.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن اختيار وقت في المستقبل')),
        );
        return;
      }

      setState(() {
        widget.session.startTime = newStartTime;
        _displayDuration = widget.session.netRunningTime;
      });
      widget.session.save();
    }
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isEditable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isEditable ? Colors.blue : null,
                decoration: isEditable ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isEditable)
            const Icon(Icons.edit, size: 12, color: Colors.blue),
        ],
      ),
    );
  }
}
