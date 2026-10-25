import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.kamaleshkkb.pharmacy',
  appName: 'PharmaCare',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
};

export default config;
