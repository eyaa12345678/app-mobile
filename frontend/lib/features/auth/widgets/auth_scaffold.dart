import 'package:flutter/material.dart';

const authPrimary = Color(0xFF087E8B);
const authInk = Color(0xFF173B49);

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon = Icons.favorite_border_rounded,
    this.showBack = false,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final bool showBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: authPrimary,
      primary: authPrimary,
      surface: Colors.white,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCE6EA)),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: scheme,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: authInk,
              displayColor: authInk,
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: authPrimary, width: 2),
          ),
          errorMaxLines: 3,
          prefixIconColor: const Color(0xFF6C838C),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
      child: PopScope(
        canPop: !busy,
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F6F8),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                return Row(
                  children: [
                    if (wide) const Expanded(child: _WelcomePanel()),
                    Expanded(
                      child: SizedBox.expand(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth < 400 ? 16 : 32,
                            vertical: 28,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      if (showBack &&
                                          Navigator.canPop(context)) ...[
                                        IconButton(
                                          tooltip: 'Retour',
                                          onPressed: busy
                                              ? null
                                              : () => Navigator.pop(context),
                                          icon: const Icon(
                                              Icons.arrow_back_rounded),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      const _Brand(),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  Container(
                                    padding: EdgeInsets.all(
                                        constraints.maxWidth < 400 ? 20 : 32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: const Color(0xFFE1EAEE)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x080C4A57),
                                          blurRadius: 32,
                                          offset: Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5F4),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Icon(icon,
                                                color: authPrimary, size: 28),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.8,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: Color(0xFF637D88),
                                            height: 1.5,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        child,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Votre santé, un jour à la fois.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF6C838C), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_hospital_rounded, color: authPrimary, size: 32),
        SizedBox(width: 10),
        Text('MediCare',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: authInk)),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF103E50), Color(0xFF087E8B)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _circle(320),
          ),
          Positioned(bottom: -180, left: -100, child: _circle(420)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text('VOTRE ESPACE SANTÉ',
                        style: TextStyle(
                            color: Color(0xFFB9EEEB),
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Prenez soin\nde vous.\nOn vous accompagne.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Vos rendez-vous, vos traitements et votre suivi de santé, réunis dans un même espace.',
                    style: TextStyle(
                        color: Color(0xFFC3DDE2), fontSize: 17, height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  const _Feature(
                      icon: Icons.calendar_month_outlined,
                      title: 'Gardez le fil',
                      subtitle: 'Retrouvez vos rendez-vous en un instant.'),
                  const SizedBox(height: 24),
                  const _Feature(
                      icon: Icons.medication_outlined,
                      title: 'Simplifiez votre quotidien',
                      subtitle: 'Organisez vos médicaments et traitements.'),
                  const SizedBox(height: 24),
                  const _Feature(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Suivez vos progrès',
                      subtitle:
                          'Consultez vos mesures de santé au même endroit.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x14FFFFFF), width: 40),
        ),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFFB9EEEB), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFFC3DDE2), height: 1.5, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
