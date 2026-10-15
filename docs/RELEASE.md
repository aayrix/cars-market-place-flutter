# Android release signing

Create an upload key locally. Run this command from the repository root; `keytool`
prompts for the passwords and certificate details:

```sh
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias apni-gari-upload
```

Keep `upload-keystore.jks` and `android/key.properties` on a secure machine. Put
the keystore at `android/upload-keystore.jks`, then create the ignored file
`android/key.properties` with these values (use the passwords entered above):

```properties
storeFile=upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=apni-gari-upload
keyPassword=YOUR_KEY_PASSWORD
```

Back up both files securely in at least two separate locations, such as an
encrypted offline backup and an organization-controlled secrets vault. Never
commit or send either file in chat. Losing the upload key can block future Play
Store updates. Enroll in Play App Signing and keep the upload key separate from
the Play signing key.

Release builds fail with a configuration message if the properties or keystore
are missing. Debug builds continue to use the normal debug signing setup.
