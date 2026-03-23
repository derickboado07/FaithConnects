import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_service.dart';

/// Full-screen call UI for voice and video calls.
/// Uses Firestore signaling; actual media handled by Agora/WebRTC when configured.
class CallScreen extends StatefulWidget {
  final String callId;
  final String convoId;
  final String peerName;
  final String type; // 'voice' or 'video'
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.callId,
    required this.convoId,
    required this.peerName,
    required this.type,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  String _status = 'ringing'; // ringing | accepted | ended
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeaker = false;
  Timer? _durationTimer;
  int _seconds = 0;
  StreamSubscription? _callSub;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Listen for call status changes
    _callSub = CallService.instance.callStream(widget.callId).listen((snap) {
      if (!snap.exists) {
        _handleCallEnded();
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final newStatus = data['status'] as String? ?? 'ended';
      if (!mounted) return;
      setState(() => _status = newStatus);

      if (newStatus == 'accepted' && _durationTimer == null) {
        _startDurationTimer();
      } else if (newStatus == 'ended') {
        _handleCallEnded();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String _formatDuration() {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _handleCallEnded() {
    _durationTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _acceptCall() async {
    await CallService.instance.acceptCall(widget.callId);
  }

  Future<void> _endCall() async {
    // If still ringing and this was incoming, it's a missed call
    if (_status == 'ringing' && widget.isIncoming) {
      await CallService.instance.sendMissedCallMessage(
        convoId: widget.convoId,
        type: widget.type,
      );
    }
    await CallService.instance.endCall(widget.callId);
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.type == 'video';
    final isRinging = _status == 'ringing';
    final isAccepted = _status == 'accepted';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Peer name & status
            Text(
              widget.peerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAccepted
                  ? _formatDuration()
                  : isRinging
                  ? (widget.isIncoming
                        ? 'Incoming ${widget.type} call...'
                        : 'Calling...')
                  : 'Call ended',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),

            const Spacer(flex: 1),

            // Pulsing avatar during ringing
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = isRinging
                    ? 1.0 + (_pulseController.value * 0.1)
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: const Color(0xFFD4AF37),
                  child: Text(
                    widget.peerName.isNotEmpty
                        ? widget.peerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Video placeholder
            if (isVideo && isAccepted)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _isCameraOff
                      ? const Icon(
                          Icons.videocam_off,
                          color: Colors.white54,
                          size: 48,
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam,
                              color: Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Video stream active',
                              style: TextStyle(color: Colors.white54),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Configure Agora App ID for live video',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

            const Spacer(flex: 1),

            // Call controls
            if (isRinging && widget.isIncoming) ...[
              // Incoming call: Accept & Reject buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Decline',
                    onTap: _endCall,
                  ),
                  _CallButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: 'Accept',
                    onTap: _acceptCall,
                  ),
                ],
              ),
            ] else if (isAccepted) ...[
              // Active call controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red.shade300 : Colors.white24,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  _CallButton(
                    icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeaker
                        ? const Color(0xFFD4AF37)
                        : Colors.white24,
                    label: 'Speaker',
                    onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                  ),
                  if (isVideo)
                    _CallButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      color: _isCameraOff
                          ? Colors.red.shade300
                          : Colors.white24,
                      label: _isCameraOff ? 'Camera On' : 'Camera Off',
                      onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                    ),
                  _CallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'End',
                    onTap: _endCall,
                  ),
                ],
              ),
            ] else ...[
              // Outgoing ringing: Cancel button — centred
              Center(
                child: _CallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'Cancel',
                  onTap: _endCall,
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
