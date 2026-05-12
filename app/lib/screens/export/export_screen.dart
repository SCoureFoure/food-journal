import 'package:flutter/material.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export Journal (CSV)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _exportGrocery,
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Export Grocery List'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _exportCsv() async {
    // TODO: implement via ExportService + share_plus
    setState(() { _errorMessage = null; _isLoading = true; });
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoading = false);
  }

  Future<void> _exportGrocery() async {
    // TODO: implement via ExportService + share_plus
    setState(() { _errorMessage = null; _isLoading = true; });
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoading = false);
  }
}
