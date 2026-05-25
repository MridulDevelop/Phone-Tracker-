import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'beacon_survice.dart'; 
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLogin = true; // toggle between login and signup
  bool _isLoading = false;
  bool  _showNameSetup = false; // for Google sign-in display name setup
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success;
    if (_isLogin) {
  success = await AuthService.signIn(
    email: _emailController.text.trim(),
    password: _passwordController.text.trim(),
  );

  if (success) {
    // Load their display name from Firestore into local storage
    await AuthService.loadAndSaveDisplayName();
  }
}else {
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter your name")),
        );
        setState(() => _isLoading = false);
        return;
      }
      success = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
      );
    }
    
    if(success){
      // Save Display Name to BeaconService for later use in advertising
      await BeaconService.setDisplayName(_nameController.text.trim());
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // Navigate to main screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyHomePage(title: 'Phone Tracker'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin
              ? "Login failed. Check your credentials."
              : "Sign up failed. Try a different email."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
  setState(() => _isLoading = true);
  final result = await AuthService.signInWithGoogle();
  if (!mounted) return;
  setState(() => _isLoading = false);

  if (result['success'] == true) {
    final googleName = result['googleName'] as String;
    
    // Check if they need to set a display name
    final needsName = await AuthService.needsDisplayName();
    if (!mounted) return;

    if (needsName) {
      // New user — pre-fill name setup with Google name
      _displayNameController.text = googleName;
      setState(() => _showNameSetup = true);
    } else {
      // Existing user — load name and go to tracker
      await AuthService.loadAndSaveDisplayName();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyHomePage(title: 'Phone Tracker'),
        ),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Google Sign In failed"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _handleNameSetup() async {
  if (_displayNameController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please enter a display name")),
    );
    return;
  }

  setState(() => _isLoading = true);

  final name = _displayNameController.text.trim();
  await BeaconService.setDisplayName(name);
  await AuthService.updateDisplayName(name);

  if (!mounted) return;
  setState(() => _isLoading = false);

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const MyHomePage(title: 'Phone Tracker'),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    if(_showNameSetup){
      return _buildNameSetupScreen();
    }
    return _buildLoginScreen();
    }

    Widget _buildNameSetupScreen(){
      return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.badge, size: 64, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                "Set Your Display Name",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This is how others will see you\nin the tracker app",
                textAlign: TextAlign.center,
                style: TextStyle(
                   color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _displayNameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Display Name",
                  hintText: "e.g. Bhai, Krishna, Dad...",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This name will be visible to nearby\ndevices running Phone Tracker",
                textAlign: TextAlign.center,
                 style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleNameSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    }

    Widget _buildLoginScreen(){
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.radar, size: 64, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                "Phone Tracker",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? "Sign in to continue" : "Create your account",
                style: TextStyle(
                   color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Display name field — only for signup
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Display Name",
                    hintText: "How others will see you in the app",
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                   border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Email auth button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? "Sign In" : "Sign Up",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "OR",
                      style: TextStyle(color: Colors.grey[500]),
                       ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Google sign in button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text(
                    "Continue with Google",
                     style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Toggle login/signup
              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Sign Up"
                      : "Already have an account? Sign In",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}