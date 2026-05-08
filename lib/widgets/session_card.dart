import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/live_session.dart';

class SessionCard extends StatefulWidget {
  final LiveSession session;
  final VoidCallback onFinish;
  final VoidCallback onCancel; // ✅ إضافة دالة الإلغاء
  final Function(bool) onToggleDowntime;

  const SessionCard({
    super.key,
    required this.session,
    required this.onFinish,
    required this.onCancel, // ✅ تمرير الدالة للمُنشئ
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
    final String? currentDeviceId = Hive.isBoxOpen('settings') ? Hive.box('settings').get('device_id') : null;
    final bool isOwner = currentDeviceId != null && currentDeviceId == widget.session.createdByDeviceId;

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
                  const SizedBox(width: 4),
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                      tooltip: 'إلغاء الجلسة',
                      onPressed: widget.onCancel,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const Divider(),
              _buildInfoRow(Icons.person, "العميل: ${widget.session.clientName}"),
              _buildInfoRow(Icons.engineering, "الفني: ${widget.session.technicianName}"),
              _buildInfoRow(
                  Icons.numbers, "أمر: ${widget.session.orderNumber}"),
              InkWell(
                onTap: isOwner ? _selectStartTime : null,
                child: _buildInfoRow(
                  Icons.access_time,
                  "وقت البدء: ${widget.session.startTime.hour.toString().padLeft(2, '0')}:${widget.session.startTime.minute.toString().padLeft(2, '0')}",
                  isEditable: isOwner,
                ),
              ),
              if (widget.session.downtimeIntervals.isNotEmpty) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: isOwner ? () => _selectDowntimeTime(true) : null,
                  child: _buildInfoRow(
                    Icons.pause_circle_filled,
                    "بدء العطل: ${widget.session.downtimeIntervals.last.start.hour.toString().padLeft(2, '0')}:${widget.session.downtimeIntervals.last.start.minute.toString().padLeft(2, '0')}",
                    isEditable: isOwner,
                    color: Colors.orange,
                  ),
                ),
                if (widget.session.downtimeIntervals.last.end != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: isOwner ? () => _selectDowntimeTime(false) : null,
                    child: _buildInfoRow(
                      Icons.play_circle_filled,
                      "نهاية العطل: ${widget.session.downtimeIntervals.last.end!.hour.toString().padLeft(2, '0')}:${widget.session.downtimeIntervals.last.end!.minute.toString().padLeft(2, '0')}",
                      isEditable: isOwner,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              if (isOwner) ...[
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
              ] else ...[
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'الماكينة تعمل الآن تحت إشراف:\n${widget.session.technicianName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

  Future<void> _selectDowntimeTime(bool isStart) async {
    if (widget.session.downtimeIntervals.isEmpty) return;
    final last = widget.session.downtimeIntervals.last;
    final currentTime = isStart ? last.start : (last.end ?? DateTime.now());

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
    );

    if (!mounted || picked == null) return;

    final now = DateTime.now();
    final newTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      picked.hour,
      picked.minute,
    );

    if (newTime.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن اختيار وقت في المستقبل')),
      );
      return;
    }

    setState(() {
      if (isStart) {
        last.start = newTime;
      } else {
        last.end = newTime;
      }
      _displayDuration = widget.session.netRunningTime;
    });
    widget.session.save();
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isEditable = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isEditable ? (color ?? Colors.blue) : null,
                fontWeight: isEditable ? FontWeight.w500 : null,
                decoration: isEditable ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isEditable)
            Icon(Icons.edit, size: 12, color: color ?? Colors.blue),
        ],
      ),
    );
  }
}
