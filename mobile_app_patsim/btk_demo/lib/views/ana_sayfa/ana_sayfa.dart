import 'package:btk_demo/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:btk_demo/services/auth_service.dart';
import 'package:btk_demo/models/user_model.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        currentUser = user;
      });
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      if (mounted) {
        context.go('/');
      }
    }
  }

  String _getWelcomeMessage() {
    if (currentUser == null) return '';

    final gender = currentUser!.gender;
    final title = gender == 'Kadın' ? 'Doktor Hanım' : 'Doktor Bey';

    return 'Hoş geldiniz $title!\nBekleyen bir sürü hastamız var,\nkolay gelsin!';
  }

  void _navigateToChat(BuildContext context, String areaCode) {
    if (currentUser == null) return;

    

    // Chat ekranına parametrelerle git
    context.go(
      '/chatscreen?area=$areaCode&doctor_gender=${currentUser!.gender}',
    );
  }

  // Alan kutucukları için veri
  final List<Map<String, dynamic>> _areas = [
    {
      'title': 'Dermatoloji',
      'area_code': 'dermatoloji',
      'icon': Image.asset(
        'assets/dermo1.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 90, 132, 146),
    },
    {
      'title': 'Endokrinoloji',
      'area_code': 'endokrinoloji',
      'icon': Image.asset(
        'assets/endokrinoloji2.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 58, 95, 107), // Daha koyu mavi
    },
    {
      'title': 'Enfeksiyon\nHastalıkları',
      'area_code': 'enfeksiyon_hastalıkları',
      'icon': Image.asset(
        'assets/enfeksiyon.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 55, 87, 98),
    },
    {
      'title': 'Gastroenteroloji',
      'area_code': 'gastroenteroloji',
      'icon': Image.asset(
        'assets/gastro1.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 122, 174, 191),
    },
    {
      'title': 'Kardiyoloji',
      'area_code': 'kardiyoloji',
      'icon': Image.asset(
        'assets/kardiyo2.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 44, 82, 94),
    },
    {
      'title': 'Nefroloji',
      'area_code': 'nefroloji',
      'icon': Image.asset(
        'assets/nefro1.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 37, 68, 79), // Koyu yeşil-mavi
    },
    {
      'title': 'Nöroloji',
      'area_code': 'nöroloji',
      'icon': Image.asset(
        'assets/noroloji4.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 86, 146, 139), // Orta yeşil-mavi
    },
    {
      'title': 'Pediatri',
      'area_code': 'pediatri',
      'icon': Image.asset(
        'assets/pedi.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 63, 112, 106), // Koyu turkuaz
    },
    {
      'title': 'Pulmonoloji',
      'area_code': 'pulmonoloji',
      'icon': Image.asset(
        'assets/pulmo2.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 52, 90, 81), // Açık turkuaz
    },
    {
      'title': 'Romatoloji',
      'area_code': 'romatoloji',
      'icon': Image.asset(
        'assets/romato1.png',
        height: 48,
        width: 48,
        fit: BoxFit.cover,
      ),
      'color': Color.fromARGB(255, 30, 65, 53),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Ana Sayfa',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.lightTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hemşire karşılama kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 80, 125, 140),
                          Color.fromARGB(255, 38, 73, 95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.lightTheme.primaryColor.withOpacity(
                            0.3,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Hemşire ikonu
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/nurse.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Karşılama mesajı
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getWelcomeMessage(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '🏥 Hastane Yönetim Sistemi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Alanlar başlığı
                  const Text(
                    'Tıbbi Alanlar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF414A4C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uzmanlığınızı seçiniz.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 16),

                  // Alan kutucukları grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                    itemCount: _areas.length,
                    itemBuilder: (context, index) {
                      final area = _areas[index];

                      return _buildAreaCard(
                        title: area['title'],
                        icon: area['icon'],
                        color: area['color'],
                        onTap: () =>
                            _navigateToChat(context, area['area_code']),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAreaCard({
    required String title,
    required Widget icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),

                borderRadius: BorderRadius.circular(12),
              ),
              child: icon,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'AI Sohbet',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
