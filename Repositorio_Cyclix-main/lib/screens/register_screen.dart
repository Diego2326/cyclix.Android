import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void register(BuildContext context) {
    if (userController.text.isEmpty ||
        passController.text.isEmpty ||
        emailController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Completa todos los campos")));
      return;
    }

    Navigator.pop(context, {
      'user': userController.text,
      'pass': passController.text
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Crear cuenta")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: userController,
              decoration: InputDecoration(labelText: "Usuario"),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Correo"),
            ),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Contraseña"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => register(context),
              child: Text("Registrarse"),
            )
          ],
        ),
      ),
    );
  }
}