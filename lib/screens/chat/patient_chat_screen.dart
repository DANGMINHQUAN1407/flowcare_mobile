import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../services/patient_chat_service.dart';

class PatientChatScreen extends StatefulWidget {
  const PatientChatScreen({super.key});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _Message {
  final String text;
  final bool isPatient;
  final PatientChatReply? reply;
  _Message(this.text, {this.isPatient = false, this.reply});
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final _service = PatientChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _sessionId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final _messages = <_Message>[
    _Message(
      'Xin chào! Bạn có thể hỏi tôi về bệnh viện hoặc lượt khám của mình.',
    ),
  ];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final message = _input.text.trim();
    if (_sending || message.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(_Message(message, isPatient: true));
      _input.clear();
    });
    _scrollToEnd();
    try {
      final reply = await _service.ask(message, _sessionId);
      if (!mounted) return;
      setState(() => _messages.add(_Message(reply.answer, reply: reply)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _error = patientErrorMessage(
          error,
          fallback: 'Không thể kết nối trợ lý. Vui lòng thử lại.',
        );
        _input.text = message;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _dial() async {
    try {
      await const MethodChannel('flowcare/emergency')
          .invokeMethod<void>('dial');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng gọi cấp cứu 115 bằng ứng dụng điện thoại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trợ lý bệnh nhân')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Trợ lý cung cấp thông tin tham khảo, không thay thế bác sĩ.',
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                return Align(
                  alignment: item.isPatient
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .85,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.isPatient
                          ? AppColors.primaryLight
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(item.text),
                        for (final card
                            in item.reply?.cards ?? <Map<String, dynamic>>[])
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              [
                                if (card['number'] != null)
                                  'Số thứ tự: ${card['number']}',
                                if (card['status'] != null)
                                  'Trạng thái: ${card['status']}',
                                if (card['waitMinutes'] != null)
                                  'Thời gian chờ: ${card['waitMinutes']} phút',
                                if (card['room'] != null)
                                  'Phòng: ${card['room']}',
                                if (card['floor'] != null)
                                  'Tầng: ${card['floor']}',
                                if (card['building'] != null)
                                  'Tòa nhà: ${card['building']}',
                                if (card['action'] != null) '${card['action']}',
                              ].join('\n'),
                            ),
                          ),
                        for (final source
                            in item.reply?.sources ?? <Map<String, dynamic>>[])
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Nguồn: ${source['doc'] ?? ''}\n${source['snippet'] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (item.reply?.emergency == true)
                          TextButton.icon(
                            onPressed: _dial,
                            icon: const Icon(Icons.phone),
                            label: const Text('Gọi cấp cứu 115'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.emergency),
              ),
            ),
          if (_sending) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_sending,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhập câu hỏi...',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  tooltip: 'Gửi',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
