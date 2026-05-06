// JobDun Galvanised — theme tokens (Flutter Material 3 ColorScheme aligned)
// Names mirror Flutter's ColorScheme so this maps 1:1 to Dart later.

const THEMES = {
  light: {
    mode: 'light',
    // surfaces
    background: '#F4F6F8',     // Scaffold background
    surface: '#FFFFFF',        // Cards
    surfaceVariant: '#EAEEF2', // Chips, search bg
    outline: '#D4D9DF',
    outlineVariant: '#E2E6EB',
    // content
    onBackground: '#252D34',
    onSurface: '#252D34',
    onSurfaceVariant: '#5A6872',
    onSurfaceMuted: '#A0ACB8',
    // brand
    primary: '#252D34',        // Foundation — used for primary buttons
    onPrimary: '#FFFFFF',
    secondary: '#CC4A10',      // Action — CTAs, distance, accents
    onSecondary: '#FFFFFF',
    secondaryContainer: '#FAE4D8',
    onSecondaryContainer: '#7A2808',
    // semantic
    success: '#0D8A5A',
    successContainer: '#E6F7F1',
    onSuccessContainer: '#0D6644',
    error: '#C73B2E',
    errorContainer: '#FDECEA',
    onErrorContainer: '#A32E24',
    info: '#1A7AD4',
    infoContainer: '#E6F3FF',
    onInfoContainer: '#1254A0',
    // chrome
    deviceShell: '#F2F2F7',
  },
  dark: {
    mode: 'dark',
    background: '#0E1216',
    surface: '#161B20',
    surfaceVariant: '#1F262C',
    outline: '#2A333B',
    outlineVariant: '#222A31',
    onBackground: '#E8ECF2',
    onSurface: '#E8ECF2',
    onSurfaceVariant: '#A0ACB8',
    onSurfaceMuted: '#5A6872',
    primary: '#E8ECF2',          // inverted — light chip on dark
    onPrimary: '#0E1216',
    secondary: '#FF6A2E',        // brightened action for dark mode contrast
    onSecondary: '#FFFFFF',
    secondaryContainer: '#3A1F12',
    onSecondaryContainer: '#FFB694',
    success: '#3FBF8B',
    successContainer: '#0F2A22',
    onSuccessContainer: '#7FE3BD',
    error: '#FF6B5E',
    errorContainer: '#33181A',
    onErrorContainer: '#FFA89F',
    info: '#5AA8F0',
    infoContainer: '#0F2638',
    onInfoContainer: '#A8D2F5',
    deviceShell: '#000000',
  },
};

const FF = { display:"'Barlow Condensed', sans-serif", body:"'Barlow', sans-serif" };

window.THEMES = THEMES;
window.FF = FF;
