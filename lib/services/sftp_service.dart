import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

class SFTPService {
  SSHClient? _client;
  SftpClient? _sftp;

  /// Connects to the SFTP server using the provided credentials.
  /// [host], [port], [username], and [password] are basic connection details.
  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    SSHKeyPair? keyPair,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port);
      
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        identities: keyPair != null ? [keyPair] : [],
      );

      // Authenticate and wait for connection
      await _client!.authenticated;
      _sftp = await _client!.sftp();
      
      return true;
    } catch (e) {
      print('Connection failed: $e');
      return false;
    }
  }

  /// Disconnects from the server.
  void disconnect() {
    _sftp = null;
    _client?.close();
    _client = null;
  }

  /// Uploads a file to the server.
  Future<bool> uploadFile(File localFile, String remotePath) async {
    if (_sftp == null) return false;
    try {
      final file = await _sftp!.open(
        remotePath, 
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );
      await file.write(localFile.openRead().cast());
      await file.close();
      return true;
    } catch (e) {
      print('Upload failed: $e');
      return false;
    }
  }

  /// Downloads a file from the server.
  Future<bool> downloadFile(String remotePath, String localPath) async {
    if (_sftp == null) return false;
    try {
      final localFile = File(localPath);
      final sink = localFile.openWrite();
      await _sftp!.download(remotePath, sink);
      await sink.close();
      return true;
    } catch (e) {
      print('Download failed: $e');
      return false;
    }
  }

  /// Returns a list of files in the given directory.
  Future<List<SftpName>> listDirectory(String path) async {
    if (_sftp == null) return [];
    try {
      return await _sftp!.listdir(path);
    } catch (e) {
      print('Listing failed: $e');
      return [];
    }
  }

  bool get isConnected => _client != null && _sftp != null;
}
