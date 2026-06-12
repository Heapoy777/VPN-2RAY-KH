import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyV2rayApp());
}

class MyV2rayApp extends StatelessWidget {
  const MyV2rayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const V2rayMainScreen(),
    );
  }
}

class V2rayMainScreen extends StatefulWidget {
  const V2rayMainScreen({super.key});

  @override
  State<V2rayMainScreen> createState() => _V2rayMainScreenState();
}

class _V2rayMainScreenState extends State<V2rayMainScreen> {
  late FlutterV2ray flutterV2ray;
  String connectionState = "DISCONNECTED";
  bool isConnected = false;
  List<Map<String, String>> serverList = [];
  int selectedIndex = -1;
  String v2rayCoreVersion = "Loading...";
  final TextEditingController _configController = TextEditingController();

  @override
  void initState() {
    super.initState();
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          connectionState = status.state.toUpperCase();
          isConnected = status.state == "CONNECTED";
        });
      },
    );
    _initV2ray();
    _loadServers();
  }

  void _initV2ray() async {
    await flutterV2ray.initializeV2ray();
    String version = await flutterV2ray.getCoreVersion();
    setState(() {
      v2rayCoreVersion = version;
    });
  }

  void _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('v2ray_servers');
    if (savedData != null) {
      setState(() {
        serverList = List<Map<String, String>>.from(
          json.decode(savedData).map((item) => Map<String, String>.from(item))
        );
      });
    }
  }

  void _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('v2ray_servers', json.encode(serverList));
  }

  void _addServer(String configLink) {
    if (configLink.startsWith("vmess://") || configLink.startsWith("vless://") || 
        configLink.startsWith("trojan://") || configLink.startsWith("ss://")) {
      String type = configLink.split('://')[0].toUpperCase();
      String name = "Server ${serverList.length + 1} ($type)";
      setState(() {
        serverList.add({"name": name, "config": configLink, "ping": "N/A"});
        if (selectedIndex == -1) selectedIndex = 0;
      });
      _saveServers();
      _configController.clear();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ទម្រង់ Config មិនត្រឹមត្រូវទេ! (vmess, vless, trojan, ss)"))
      );
    }
  }

  void _testPing(int index) async {
    setState(() { serverList[index]['ping'] = "..."; });
    int pingResult = await flutterV2ray.getServerDelay(config: serverList[index]['config']!);
    setState(() {
      serverList[index]['ping'] = pingResult == -1 ? "Timeout" : "${pingResult}ms";
    });
  }

  void _toggleConnection() async {
    if (isConnected) {
      flutterV2ray.stopV2ray();
    } else {
      if (selectedIndex == -1 || serverList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("សូមជ្រើសរើស Server មួយជាមុនសិន!"))
        );
        return;
      }
      if (await flutterV2ray.requestPermission()) {
        flutterV2ray.startV2ray(
          remark: serverList[selectedIndex]['name']!,
          config: serverList[selectedIndex]['config']!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ចិន សុជាតិ V2RAY PRO'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link, color: Colors.cyanAccent),
            onPressed: () => _showAddServerDialog(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("បញ្ជី Server របស់អ្នក:", style: TextStyle(fontSize: 16, color: Colors.grey)),
                Text("Core: $v2rayCoreVersion", style: const TextStyle(fontSize: 12, color: Colors.cyan)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: serverList.isEmpty
                  ? const Center(child: Text("មិនទាន់មាន Server ទេ! សូមចុចប៊ូតុងខាងលើដើម្បីថែម។", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: serverList.length,
                      itemBuilder: (context, index) => _buildServerTile(index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isConnected ? Colors.cyanAccent : Colors.pinkAccent.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.vpn_lock, size: 60, color: isConnected ? Colors.cyanAccent : Colors.grey),
          const SizedBox(height: 10),
          Text(
            connectionState,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isConnected ? Colors.cyanAccent : Colors.pinkAccent, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.pinkAccent : Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
            ),
            onPressed: _toggleConnection,
            child: Text(isConnected ? "STOP VPN" : "START VPN", style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildServerTile(int index) {
    bool isSelected = index == selectedIndex;
    return Card(
      color: isSelected ? const Color(0xFF21262D) : const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.transparent)
      ),
      child: ListTile(
        leading: Icon(Icons.lan, color: isSelected ? Colors.cyanAccent : Colors.grey),
        title: Text(serverList[index]['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Ping: ${serverList[index]['ping']!}", style: const TextStyle(color: Colors.greenAccent)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.flash_on, color: Colors.amberAccent), onPressed: () => _testPing(index)),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  serverList.removeAt(index);
                  if (selectedIndex >= serverList.length) selectedIndex = serverList.length - 1;
                });
                _saveServers();
              },
            ),
          ],
        ),
        onTap: () { setState(() { selectedIndex = index; }); },
      ),
    );
  }

  void _showAddServerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("បន្ថែម Server គ្រប់ទម្រង់"),
        backgroundColor: const Color(0xFF161B22),
        content: TextField(
          controller: _configController,
          decoration: const InputDecoration(hintText: "vmess:// ឬ vless://...", border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("បោះបង់", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () => _addServer(_configController.text.trim()),
            child: const Text("យល់ព្រម"),
          ),
        ],
      ),
    );
  }
}
