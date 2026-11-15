import 'package:flutter/material.dart';

void main() => runApp(const RiderApp());

const ink = Color(0xFF1B1F3B);
const violet = Color(0xFF3D348B);
const steps = ['Arrived', 'Started', 'Finished'];

// ============================================================
//  MODELS
// ============================================================

/// How a job step was proven. Proof counts more than claims.
enum Tier { self, nfc, signed }

extension TierInfo on Tier {
  String get label => switch (this) {
        Tier.self => 'Self-report',
        Tier.nfc => 'NFC tap',
        Tier.signed => 'Badge signed',
      };
  String get hint => switch (this) {
        Tier.self => 'Just tap a button. Counts least.',
        Tier.nfc => 'Tap the tag at the customer\'s place.',
        Tier.signed => 'Signed by your badge. Counts most.',
      };

  /// Weights used for the trust score (change here to tune).
  double get lr => switch (this) {
        Tier.self => 1.1,
        Tier.nfc => 1.3,
        Tier.signed => 1.8,
      };
  Color get color => switch (this) {
        Tier.self => const Color(0xFF7A7F85),
        Tier.nfc => const Color(0xFFC77D0A),
        Tier.signed => const Color(0xFF0F7B5F),
      };
  IconData get icon => switch (this) {
        Tier.self => Icons.touch_app_outlined,
        Tier.nfc => Icons.nfc,
        Tier.signed => Icons.verified_outlined,
      };
}

class JobEvent {
  final String type;
  final Tier tier;
  final bool good;
  final DateTime time;
  JobEvent(this.type, this.tier, this.good, this.time);
}

class Rider {
  final String name, trade, town;
  final List<JobEvent> events;
  Rider(this.name, this.trade, this.town, this.events);

  double get odds {
    var o = 1.0;
    for (final e in events) {
      o *= e.good ? e.tier.lr : 1 / e.tier.lr;
    }
    return o;
  }

  double get score => odds / (1 + odds);
  int count(Tier t) => events.where((e) => e.tier == t).length;
  String get initials => name.split(' ').map((p) => p[0]).take(2).join();
}

class Req {
  final int id;
  final String title, from, address, fee;
  final List<JobEvent> events = [];
  Req(this.id, this.title, this.from, this.address, this.fee);
}

List<JobEvent> _hist(String spec) {
  final parts = spec.split(' ');
  final now = DateTime.now();
  return [
    for (var i = 0; i < parts.length; i++)
      JobEvent(
        'Past job',
        switch (parts[i][0]) {
          'S' => Tier.signed,
          'N' => Tier.nfc,
          _ => Tier.self,
        },
        parts[i][1] == '+',
        now.subtract(Duration(days: parts.length - i)),
      ),
  ];
}

// ============================================================
//  STORE (fake data, replace with the FastAPI service later)
// ============================================================

class Store extends ChangeNotifier {
  final rider = Rider(
      'Rahim Baloch', 'Rider', 'Turbat', _hist('S+ S+ N+ S+ S+ N+ S+ N+ S-'));
  final List<Req> requests = [
    Req(1, 'Parcel to Hospital Road', 'Ali Khan', 'Main Bazaar, Turbat',
        'Rs 300'),
    Req(2, 'Pick up medicine', 'Sana Baloch', 'Satellite Town', 'Rs 250'),
    Req(3, 'Deliver documents', 'Dr. Karim', 'Airport Road', 'Rs 400'),
  ];
  final List<Req> done = [];
  final List<JobEvent> queue = []; // events waiting to sync
  Req? active;
  bool online = true;

  void accept(Req r) {
    if (active != null) return;
    requests.remove(r);
    active = r;
    notifyListeners();
  }

  void decline(Req r) {
    requests.remove(r);
    notifyListeners();
  }

  void setOnline(bool v) {
    online = v;
    notifyListeners();
  }

  /// Records the next step. Online: counts now. Offline: waits in the queue.
  void record(Tier t) {
    final j = active;
    if (j == null) return;
    final e = JobEvent(steps[j.events.length], t, true, DateTime.now());
    j.events.add(e);
    (online ? rider.events : queue).add(e);
    if (j.events.length == steps.length) {
      done.add(j);
      active = null;
    }
    notifyListeners();
  }

  (double, double)? sync() {
    if (!online || queue.isEmpty) return null;
    final before = rider.score;
    rider.events.addAll(queue);
    queue.clear();
    notifyListeners();
    return (before, rider.score);
  }
}

final store = Store();

// ============================================================
//  APP
// ============================================================

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustTier Rider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: violet).copyWith(primary: violet),
        scaffoldBackgroundColor: const Color(0xFFF4F4F8),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFE2DEFA),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [JobsPage(), ScorePage(), BadgePage()],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.two_wheeler), label: 'Jobs'),
            const NavigationDestination(
                icon: Icon(Icons.shield_outlined), label: 'My score'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: store.queue.isNotEmpty,
                label: Text('${store.queue.length}'),
                child: const Icon(Icons.bluetooth),
              ),
              label: 'Badge',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  SHARED WIDGETS
// ============================================================

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String pct(double v) => (v * 100).toStringAsFixed(1);

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

class Header extends StatelessWidget {
  final String title, subtitle;
  const Header(this.title, this.subtitle, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ink, violet]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  const Panel({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E6EE)),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, this.color, {this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class TierChip extends StatelessWidget {
  final Tier tier;
  const TierChip(this.tier, {super.key});

  @override
  Widget build(BuildContext context) =>
      Pill(tier.label, tier.color, icon: tier.icon);
}

/// Ring length = trust score. Ring colours = mix of evidence behind it.
class ScoreRing extends StatelessWidget {
  final Rider rider;
  final double size;
  const ScoreRing(this.rider, {this.size = 120, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(rider, size / 8),
        child: Center(
          child: Text('${(rider.score * 100).round()}',
              style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                  color: ink)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Rider rider;
  final double stroke;
  _RingPainter(this.rider, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    const full = 6.2832;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE3E9ED);
    canvas.drawArc(rect, 0, full, false, p);
    if (rider.events.isEmpty) return;
    final total = rider.score * full;
    var from = -1.5708;
    for (final t in [Tier.signed, Tier.nfc, Tier.self]) {
      final sweep = total * rider.count(t) / rider.events.length;
      if (sweep <= 0) continue;
      p.color = t.color;
      canvas.drawArc(rect, from, sweep, false, p);
      from += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => true;
}

// ============================================================
//  JOBS TAB
// ============================================================

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Header('My jobs', 'Accept a job, then prove each step.'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (store.active != null) ...[
                    const SectionTitle('Current job'),
                    ActiveCard(store.active!),
                  ],
                  const SectionTitle('New requests'),
                  if (store.requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('No new requests right now.'),
                    ),
                  for (final r in store.requests) RequestCard(r),
                  if (store.done.isNotEmpty)
                    Text('${store.done.length} job(s) finished this session',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final Req r;
  const RequestCard(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final busy = store.active != null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${r.from}, ${r.address}'),
          const SizedBox(height: 12),
          Row(
            children: [
              Pill(r.fee, const Color(0xFF0F7B5F),
                  icon: Icons.payments_outlined),
              const Spacer(),
              TextButton(
                  onPressed: () => store.decline(r),
                  child: const Text('Decline')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : () => store.accept(r),
                child: const Text('Accept'),
              ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Finish your current job first.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

class ActiveCard extends StatelessWidget {
  final Req job;
  const ActiveCard(this.job, {super.key});

  void record(BuildContext context, Tier t) {
    final before = store.rider.score;
    store.record(t);
    final prefix = store.active == null ? 'Job finished. ' : '';
    toast(
        context,
        store.online
            ? '${prefix}Score ${pct(before)} to ${pct(store.rider.score)}'
            : '${prefix}Saved on your phone. Sync it on the Badge tab.');
  }

  @override
  Widget build(BuildContext context) {
    final next = steps[job.events.length];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Pill('In progress', Color(0xFFC77D0A)),
          const SizedBox(height: 10),
          Text(job.title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('${job.from}, ${job.address}'),
          const Divider(height: 28),
          for (var i = 0; i < steps.length; i++)
            _StepRow(steps[i], i < job.events.length ? job.events[i] : null),
          const SizedBox(height: 12),
          Text('Prove "$next" with:',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final t in Tier.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => record(context, t),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.color.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: t.color.withOpacity(0.12),
                      child: Icon(t.icon, color: t.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(t.hint, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
          if (!store.online)
            const Text('Badge is offline. Events will wait on the Badge tab.',
                style: TextStyle(fontSize: 12, color: Color(0xFFB3382C))),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final JobEvent? event;
  const _StepRow(this.label, this.event);

  @override
  Widget build(BuildContext context) {
    final done = event != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF0F7B5F) : Colors.grey),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: done ? null : Colors.grey)),
        const Spacer(),
        if (event != null) ...[
          TierChip(event!.tier),
          const SizedBox(width: 8),
          Text(hm(event!.time), style: const TextStyle(fontSize: 12)),
        ],
      ]),
    );
  }
}

// ============================================================
//  SCORE TAB
// ============================================================

class ScorePage extends StatelessWidget {
  const ScorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final r = store.rider;
        final recent = r.events.reversed.take(6).toList();
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Header(
                  'My trust score', 'Proof raises it faster than claims.'),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Panel(
                      child: Column(children: [
                        ScoreRing(r, size: 140),
                        const SizedBox(height: 12),
                        Text(r.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('${r.trade}, ${r.town}'),
                        const SizedBox(height: 6),
                        Text('${r.events.length} events counted',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    Panel(
                      child: Column(children: [
                        for (final t in [Tier.signed, Tier.nfc, Tier.self])
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(t.icon, color: t.color),
                            title: Text(t.label),
                            subtitle: Text(t.hint),
                            trailing: Text(
                                '${r.count(t)} events\nweight x${t.lr}',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ]),
                    ),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recent events',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          for (final e in recent)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                e.good ? Icons.check_circle : Icons.cancel,
                                color: e.good
                                    ? const Color(0xFF0F7B5F)
                                    : const Color(0xFFB3382C),
                              ),
                              title: Text(e.type),
                              trailing: TierChip(e.tier),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
//  BADGE TAB
// ============================================================

class BadgePage extends StatelessWidget {
  const BadgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final canSync = store.online && store.queue.isNotEmpty;
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Header('Badge & sync', 'Works without internet.'),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Panel(
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Connected to internet',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text(
                              'Turn this off to test doing jobs offline.'),
                          value: store.online,
                          onChanged: store.setOnline,
                        ),
                      ),
                    ),
                    const SectionTitle('Waiting to sync'),
                    Panel(
                      child: store.queue.isEmpty
                          ? const Text(
                              'Nothing waiting. All events are synced.')
                          : Column(children: [
                              for (final e in store.queue)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.schedule),
                                  title: Text(e.type),
                                  subtitle: Text(hm(e.time)),
                                  trailing: TierChip(e.tier),
                                ),
                            ]),
                    ),
                    FilledButton.icon(
                      onPressed: canSync
                          ? () {
                              final r = store.sync();
                              if (r != null) {
                                toast(context,
                                    'Synced. Score ${pct(r.$1)} to ${pct(r.$2)}');
                              }
                            }
                          : null,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                    if (!store.online && store.queue.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Go online to sync.',
                            style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    Panel(
                      child: Text(
                        'Each signed event is linked to the one before it. If anyone edits your history, the link breaks and the server can see it. Events only change your score after they sync.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
