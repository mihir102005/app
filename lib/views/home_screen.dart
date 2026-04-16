import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:keepsafe/viewmodels/file_provider.dart';
import 'package:keepsafe/models/file_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        return PopScope(
          canPop: fileProvider.isAtRoot,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await fileProvider.navigateUp();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keepsafe'),
                  Text(
                    fileProvider.currentPath,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.cyanAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () => _showCreateFolderDialog(context, fileProvider),
                  tooltip: 'Create Folder',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: fileProvider.fetchFiles,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            body: fileProvider.isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting to server...', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : fileProvider.files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            const Text('No files found', style: TextStyle(color: Colors.white60)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: fileProvider.files.length,
                        itemBuilder: (context, index) {
                          final file = fileProvider.files[index];
                          return FileTile(file: file);
                        },
                      ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                debugPrint('Upload tapped');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upload placeholder (Phase 3)')),
                );
              },
              child: const Icon(Icons.file_upload_outlined),
            ),
            bottomNavigationBar: fileProvider.isMovingItem
                ? BottomAppBar(
                    color: const Color(0xFF0F172A),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Moving: ${fileProvider.itemToMove?.name ?? 'Unknown'}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: fileProvider.cancelMove,
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isMoveValid(fileProvider) 
                                ? fileProvider.completeMove 
                                : () => _showInvalidMoveSnackBar(context, fileProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMoveValid(fileProvider) 
                                  ? const Color(0xFFFACC15) 
                                  : Colors.grey,
                            ),
                            child: const Text('Move Here'),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  bool _isMoveValid(FileProvider provider) {
    if (provider.itemToMove == null) return false;
    
    // 1. Check if same directory (using new sourceDirectory state)
    if (provider.currentPath == provider.sourceDirectory) return false;

    // 2. Check if moving folder into itself
    if (provider.itemToMove!.isDirectory && provider.currentPath.startsWith(provider.itemToMove!.path)) {
      return false;
    }

    return true;
  }

  void _showInvalidMoveSnackBar(BuildContext context, FileProvider provider) {
    String message = 'Invalid move destination';
    
    if (provider.currentPath == provider.sourceDirectory) {
      message = 'Item is already in this folder';
    } else if (provider.itemToMove!.isDirectory && provider.currentPath.startsWith(provider.itemToMove!.path)) {
      message = 'Cannot move a folder into itself';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showCreateFolderDialog(BuildContext context, FileProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createFolder(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class FileTile extends StatelessWidget {
  final FileItem file;

  const FileTile({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FileProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF1E293B), // Slate Slate
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => provider.navigateToFolder(file),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: file.isDirectory ? Colors.blue.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            file.isDirectory ? Icons.folder : Icons.insert_drive_file,
            color: file.isDirectory ? Colors.blueAccent : Colors.amberAccent,
          ),
        ),
        title: Text(
          file.name,
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
        ),
        subtitle: Text(
          file.isDirectory ? 'Folder' : '${(file.size / 1024).toStringAsFixed(1)} KB',
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) {
                if (value == 'move') {
                  provider.initiateMove(file);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_move_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Move'),
                    ],
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
