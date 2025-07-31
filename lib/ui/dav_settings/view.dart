import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../model/webdav.dart';
import 'model.dart';

class DavSettingsView extends StatelessWidget {
  const DavSettingsView({super.key, required this.model});
  final DavSettingsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.keyboard_arrow_left, size: 32),
        ),
        title: Text('Settings'),
      ),
      body: ListenableBuilder(
        // listenable: model.load,
        listenable: model,
        builder: (context, _) => model.loading
            // builder: (context, _) => model.load.running
            ? Center(child: CircularProgressIndicator())
            : model.error != ""
            // : model.load.error
            ? Center(child: Text(model.error))
            // ? Center(child: Text(model.load.error.toString()))
            : SingleChildScrollView(child: ServerSettings(model: model)),
      ),
    );
  }
}

class ServerSettings extends StatefulWidget {
  const ServerSettings({super.key, required this.model});
  final DavSettingsViewModel model;

  @override
  State<ServerSettings> createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<ServerSettings> {
  bool _obscurePassword = true;
  // ignore: unused_field
  final _logger = Logger('ServerSettings');
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _rootDirController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.model.server.title;
    _serverUrlController.text = widget.model.server.url;
    _rootDirController.text = widget.model.server.root;
    _usernameController.text = widget.model.server.auth.username ?? '';
    _passwordController.text = widget.model.server.auth.password ?? '';
    _authUrlController.text = widget.model.server.auth.authUrl ?? '';
  }

  Future<String> _update() async {
    // final data = <String, dynamic>{};
    final server = widget.model.server;
    // title
    // data["title"] = _titleController.text.trim();
    server.title = _titleController.text.trim();
    // url
    // data["url"] = _serverUrlController.text.trim();
    // if (!data["url"].startsWith('https://')) {
    //   data["url"] = 'https://${data["url"]}';
    // }
    server.url = _serverUrlController.text.trim();
    if (!server.url.startsWith('https://')) {
      server.url = 'https://${server.url}';
    }
    // root
    // data["root"] = _rootDirController.text.trim();
    // if (!data["root"].startsWith('/')) {
    //   data["root"] = '/${data["root"]}';
    // }
    server.root = _rootDirController.text.trim();
    if (!server.root.startsWith('/')) {
      server.root = '/${server.root}';
    }
    // if (data["root"].endsWith('/')) {
    //   data["root"] = data["root"].substring(0, data["root"].length - 1);
    // }
    if (server.root.endsWith('/')) {
      server.root = server.root.substring(0, server.root.length - 1);
    }
    // auth
    // final auth = widget.model.server.auth;
    if (server.auth.method == AuthMethod.basic) {
      // basic auth
      server.auth.username = _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim();
      server.auth.password = _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim();
    } else if (server.auth.method == AuthMethod.nubis) {
      // nubis
      server.auth.username = _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim();
      server.auth.password = _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim();
      server.auth.authUrl = _authUrlController.text.trim();
      if (!server.auth.authUrl!.startsWith('https://')) {
        server.auth.authUrl = 'https://${server.auth.authUrl}';
      }
      server.auth.scope = "offline_access authelia.bearer.authz";
      server.auth.audience = server.url;
      server.auth.redirectUri = "${server.auth.username}:/oauthredirect";
      // fetch additional info
      final oidcnf = await _fetchWellKnownData(server.auth.authUrl!);
      if (oidcnf == null) {
        return 'Auth server error: Check URL';
      } else {
        server.auth.extra = oidcnf;
      }
    }
    // add auth element to the data
    // data["auth"] = jsonEncode(auth.toSqlite());
    // data['auth'] = auth;
    return await widget.model.updateServer(server);
  }

  Future<Map<String, dynamic>?> _fetchWellKnownData(String url) async {
    try {
      final res = await http.get(
        Uri.parse("$url/.well-known/openid-configuration"),
      );
      if (res.statusCode == 200) {
        final payload = jsonDecode(res.body);
        return {
          "authEp": payload["authorization_endpoint"],
          "tokenEp": payload["token_endpoint"],
          "introspectEp": payload["introspection_endpoint"],
          "revokeEp": payload["revocation_endpoint"],
          "parEp": payload["pushed_authorization_request_endpoint"],
          "userinfoEp": payload["userinfo_endpoint"],
        };
      }
    } on Exception catch (e) {
      _logger.warning(e.toString());
    }
    return null;
  }

  String? _passwordValidator(String? value) =>
      value is String && value.trim().length >= 8
      ? null
      : "at least 8 characters required";

  String? _usernameValidator(String? value) =>
      value is String && value.trim().length >= 5
      ? null
      : "at least 5 characters required";

  String? _urlValidator(String? value) =>
      value is String && value.trim().length >= 5 && value.contains('.')
      ? null
      : "invalid url";

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          spacing: 16,
          children: [
            Column(
              spacing: 16,
              children: [
                // title
                TextFormField(
                  controller: _titleController,
                  validator: _usernameValidator,
                  decoration: InputDecoration(
                    labelText: 'title',
                    // border: OutlineInputBorder(),
                  ),
                  // onChanged: (value) => widget.server.url =
                  //     value.startsWith('http') ? value : 'https://$value',
                ),
                // url
                TextFormField(
                  controller: _serverUrlController,
                  validator: _urlValidator,
                  decoration: InputDecoration(
                    labelText: 'url',
                    // border: OutlineInputBorder(),
                  ),
                  // onChanged: (value) => widget.server.url =
                  //     value.startsWith('http') ? value : 'https://$value',
                ),
                // root directory
                TextFormField(
                  controller: _rootDirController,
                  decoration: InputDecoration(
                    labelText: 'root directory',
                    // border: OutlineInputBorder(),
                  ),
                  // onChanged: (value) => widget.server.root =
                  //     value.startsWith('/') ? value : '/$value',
                ),
              ],
            ),
            // auth method
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Authentication Method',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                DropdownButton(
                  // isExpanded: true,
                  value: widget.model.server.auth.method.name,
                  onChanged: (value) => setState(
                    () => widget.model.server.auth.method = AuthMethod.values
                        .byName(value!),
                  ),
                  items: AuthMethod.values
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.name,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            widget.model.server.auth.method == AuthMethod.none
                ? SizedBox() // no auth
                : widget.model.server.auth.method == AuthMethod.nubis
                ? Column(
                    // authelia with PAR
                    spacing: 16,
                    children: [
                      TextFormField(
                        controller: _authUrlController,
                        validator: _urlValidator,
                        decoration: InputDecoration(
                          labelText: 'auth server',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      // client id
                      TextFormField(
                        controller: _usernameController,
                        validator: _usernameValidator,
                        decoration: InputDecoration(
                          labelText: 'client ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      // client secret
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: _passwordValidator,
                        decoration: InputDecoration(
                          labelText: 'client secret',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: _obscurePassword
                                ? Icon(Icons.visibility)
                                : Icon(Icons.visibility_off_outlined),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      // clear token
                      widget.model.server.auth.accessToken != null
                          ? TextButton(
                              child: Text("delete token"),
                              onPressed: () async {
                                await widget.model.deleteTokens();
                                setState(() {});
                              },
                            )
                          : SizedBox(),
                    ],
                  )
                : Column(
                    // basic auth
                    spacing: 16,
                    children: [
                      // username
                      TextFormField(
                        controller: _usernameController,
                        validator: _usernameValidator,
                        decoration: InputDecoration(
                          labelText: 'username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      // password
                      TextFormField(
                        controller: _passwordController,
                        validator: _passwordValidator,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'password',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: _obscurePassword
                                ? Icon(Icons.visibility)
                                : Icon(Icons.visibility_off_outlined),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            widget.model.server.id != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 16.0,
                    children: [
                      FilledButton(
                        child: Text('Update'),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final res = await _update();
                            if (context.mounted) {
                              FocusScope.of(context).unfocus();
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(res)));
                            }
                          }
                        },
                      ),
                      FilledButton.tonal(
                        child: Text('Delete', style: errorStyle),
                        onPressed: () async {
                          await widget.model.deleteServer();
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 16.0,
                    children: [
                      FilledButton(
                        child: Text('Create'),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final res = await _update();
                            if (context.mounted) {
                              FocusScope.of(context).unfocus();
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(res)));
                            }
                          }
                        },
                      ),
                      FilledButton.tonal(
                        child: Text('Cancel', style: errorStyle),
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class Instruction extends StatelessWidget {
  const Instruction({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: SizedBox());
  }
}
