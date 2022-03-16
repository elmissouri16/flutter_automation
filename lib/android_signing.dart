part of flutter_automation;

String? alias;
String keystorePath = "keys/keystore.jks";
String? keyPass;
String? keystorePass;
const String keyPropertiesPath = "./android/key.properties";

/// Main function that uses other helper functions to setup android signing
void _androidSign() {
  _generateKeystore();
  _createKeyProperties();
  _configureBuildConfig();
}

/// Generates the keystore with the given settings
void _generateKeystore() {
  String defDname =
      "CN=popupbits.com, OU=DD, O=Popup Bits Ltd., L=Kathmandu, S=Bagmati, C=NP";

  stdout.write("enter key alias: ");
  alias = stdin.readLineSync();

  stdout.write(
      "enter dname as (CN=popupbits.com, OU=DD, O=Popup Bits Ltd., L=Kathmandu, S=Bagmati, C=NP): ");
  String? dname = stdin.readLineSync();
  if (dname == null || dname.isEmpty) dname = defDname;
  stdout.write("key password: ");
  keyPass = stdin.readLineSync();
  stdout.write("keystore password: ");
  keystorePass = stdin.readLineSync();
  if (alias == null || alias!.isEmpty ||
      dname.isEmpty ||
      keyPass == null || keyPass!.isEmpty ||
      keystorePass == null || keystorePass!.isEmpty) {
    stderr.writeln("All inputs that don't have default mentioned are required");
    return;
  }

  Directory keys = Directory("keys");
  if (!keys.existsSync()) {
    keys.createSync();
  }

  ProcessResult res = Process.runSync("keytool", [
    "-genkey",
    "-noprompt",
    "-alias",
    alias!,
    "-dname",
    dname,
    "-keystore",
    keystorePath,
    "-storepass",
    keystorePass!,
    "-keypass",
    keyPass!,
    "-keyalg",
    "RSA",
    "-keysize",
    "2048",
    "-validity",
    "10000",
    "-storetype",
    "JKS"
  ]);
  stdout.write(res.stdout);
  stderr.write(res.stderr);
  stdout.writeln("generated keystore with provided input");
}

/// Creates key.properties file required by signing config in build.gradle file
void _createKeyProperties() {
  _Commons.writeStringToFile(keyPropertiesPath, """storePassword=$keystorePass
keyPassword=$keyPass
keyAlias=$alias
storeFile=../../$keystorePath
""");
  stdout.writeln("key properties file created");
}

/// configures build.gradle with release config with the generated key details
void _configureBuildConfig() {
  String bfString = _Commons.getFileAsString(_Commons.appBuildPath);
  List<String> buildfile = _Commons.getFileAsLines(_Commons.appBuildPath);
  if (!bfString.contains("deft keystoreProperties") &&
      !bfString.contains("keystoreProperties['keyAlias']")) {
    buildfile = buildfile.map((line) {
      if (line.contains(RegExp("android.*{"))) {
        return """
  def keystoreProperties = new Properties()
  def keystorePropertiesFile = rootProject.file('key.properties')
  if (keystorePropertiesFile.exists()) {
      keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
  }

  android {
              """;
      } else if (line.contains(RegExp("buildTypes.*{"))) {
        return """
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
              """;
      } else if (line.contains("signingConfig signingConfigs.debug")) {
        return "            signingConfig signingConfigs.release";
      } else {
        return line;
      }
    }).toList();

    _Commons.writeStringToFile(_Commons.appBuildPath, buildfile.join("\n"));
    stdout.writeln("configured release configs");
  } else {
    stdout.writeln("release configs already configured");
  }
}
