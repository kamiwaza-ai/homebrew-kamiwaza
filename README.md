# Kamiwaza Homebrew Tap

This tap provides Homebrew formulae for installing Kamiwaza, the enterprise AI platform for distributed model serving and vector databases.

## Installation

### Latest Version
```bash
brew tap kamiwaza-ai/kamiwaza
brew install kamiwaza
```

### Specific Version
```bash
# Install a specific version (if available in the tap)
brew install kamiwaza@0.5.0

# Or install from a specific formula revision
brew install https://raw.githubusercontent.com/kamiwaza-ai/homebrew-kamiwaza/<commit-sha>/Formula/kamiwaza.rb
```

### Switching Between Versions
```bash
# List available versions
brew list --versions kamiwaza

# Switch to a different installed version
brew switch kamiwaza 0.5.0

# Or unlink current and link specific version
brew unlink kamiwaza
brew link kamiwaza@0.5.0
```

### Version Management Notes

- The main `kamiwaza` formula always installs the latest stable version
- To maintain multiple versions, we can create versioned formulae (e.g., `kamiwaza@0.5.0.rb`)
- Each formula revision in git history represents a specific version
- For production environments, consider pinning to a specific formula revision

## Available Formulae

### kamiwaza

The main Kamiwaza platform package, including:
- Distributed model serving with Ray
- Vector database integration (Milvus/Qdrant)
- Multi-engine inference support (LlamaCpp, VLLM, MLX)
- Web-based management interface
- API endpoints for AI applications

## Configuration

### Environment Variables

You can configure the installation with these environment variables:

- `HOMEBREW_KAMIWAZA_LITE`: Set to `false` for full installation (default: `true`)
- `HOMEBREW_KAMIWAZA_LICENSE_KEY`: Your license key (optional)

Example:
```bash
export HOMEBREW_KAMIWAZA_LITE=false
export HOMEBREW_KAMIWAZA_LICENSE_KEY=your-license-key
brew install kamiwaza
```

## Usage

After installation, you can:

```bash
# Start Kamiwaza services
kamiwaza start

# Check status
kamiwaza status

# Stop services
kamiwaza stop

# Use Homebrew services
brew services start kamiwaza
brew services stop kamiwaza
```

## Documentation

For detailed documentation, visit [https://docs.kamiwaza.ai](https://docs.kamiwaza.ai)

## Support

- Documentation: [https://docs.kamiwaza.ai](https://docs.kamiwaza.ai)
- Issues: [https://github.com/kamiwaza-ai/kamiwaza/issues](https://github.com/kamiwaza-ai/kamiwaza/issues)
- Community: [https://discord.gg/kamiwaza](https://discord.gg/kamiwaza)

## License

The formulae in this tap are provided under the MIT License. The Kamiwaza software itself is distributed under its own license terms - see the installation for details.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

---

© 2024 Kamiwaza AI. All rights reserved.