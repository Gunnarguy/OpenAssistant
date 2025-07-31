# OpenAssistant Installation Guide

## For End Users

### Prerequisites
- iOS device running iOS 15.0 or later
- Xcode 15+ (for building the app)
- Valid OpenAI API key with API access

### Option 1: Building from Source (Recommended)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Gunnarguy/OpenAssistant.git
   cd OpenAssistant
   ```

2. **Open in Xcode**:
   ```bash
   open OpenAssistant.xcodeproj
   ```

3. **Configure Signing**:
   - Select your development team in Xcode
   - Change the bundle identifier to something unique (e.g., `com.yourname.openassistant`)

4. **Build and Run**:
   - Connect your iPhone/iPad
   - Select your device as the target
   - Click Run (⌘+R)

5. **Setup OpenAI API Key**:
   - When first launching the app, go to Settings
   - Enter your OpenAI API key
   - Save settings

### Option 2: TestFlight (If Available)
If the developer has published to TestFlight, you can install via:
- [TestFlight invitation link would go here]

## Getting an OpenAI API Key

1. Visit [OpenAI API Platform](https://platform.openai.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Create a new API key
5. Copy the key (keep it secure!)
6. Add billing information for API usage

⚠️ **Important**: API usage incurs charges based on OpenAI's pricing. Monitor your usage in the OpenAI dashboard.

## Troubleshooting

### Build Issues
- Ensure you're using Xcode 15+
- Clean build folder (Product → Clean Build Folder)
- Check that iOS deployment target is 15.0+

### Runtime Issues
- Verify your API key is valid
- Check internet connection
- Review OpenAI API usage limits

## Support
For issues, please check the [GitHub Issues](https://github.com/Gunnarguy/OpenAssistant/issues) page.
