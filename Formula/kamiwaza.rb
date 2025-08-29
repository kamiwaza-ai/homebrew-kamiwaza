require "uri"

class Kamiwaza < Formula
  desc "Enterprise AI platform for distributed model serving and vector databases"
  homepage "https://kamiwaza.ai"
  version "0.7.0-dev3"
  
  # Dynamic URL selection based on environment variable
  if ENV["HOMEBREW_KAMIWAZA_LOCAL_BUILD"]
    # Local filesystem URL for testing production builds
    package_dir = ENV["HOMEBREW_KAMIWAZA_PACKAGE_DIR"] || Dir.pwd
    url "file://#{package_dir}/kamiwaza-#{version}-macos.tar.gz"
    # Use actual SHA256 for local builds to avoid verification issues
    sha256 "4a1da55f75220053b56608a169569ef032cd5144c1dba8f9945b28b3a1da4366"
  else
    # Production URL from GitHub releases
    url "https://github.com/kamiwaza-ai/homebrew-kamiwaza/releases/download/v#{version}/kamiwaza-#{version}-macos.tar.gz"
    sha256 "4a1da55f75220053b56608a169569ef032cd5144c1dba8f9945b28b3a1da4366"  # This will be updated by the build process
  end
  
  license "Proprietary"

  depends_on "python@3.10"
  depends_on "node@22" 
  depends_on "cockroachdb/tap/cockroach"
  depends_on "cairo"
  depends_on "pygobject3"
  depends_on "cfssl"
  depends_on "etcd"
  depends_on "jq"
  depends_on "llama.cpp"
  depends_on "git"
  depends_on "curl"
  depends_on "coreutils"
  # Note: Docker Desktop should be installed separately:
  # depends_on cask: "docker"

  def install
    # Read environment variable (macOS only supports KAMIWAZA_LITE)
    lite_mode = ENV["HOMEBREW_KAMIWAZA_LITE"] || "true"
    
    # Telemetry configuration
    # Default: telemetry is enabled unless user explicitly opts out
    telemetry_enabled = ENV["HOMEBREW_KAMIWAZA_TELEMETRY"] != "false"
    analytics_url = ENV["KAMIWAZA_ANALYTICS_URL"] || "https://kamiwaza-ops-stage-kamiwaza-telemetry-api-326262112557.us-central1.run.app/v1/events"
    
    # License key configuration
    license_key = ENV["HOMEBREW_KAMIWAZA_LICENSE_KEY"] || "COMMUNITY-EDITION-ONLY"
    
    # Check if this is a reinstall by looking for setup completion marker
    setup_already_complete = (libexec/".kamiwaza_setup_complete").exist?
    if setup_already_complete
      opoo "Detected previous installation. Preserving existing configuration."
    end
    
    # Install everything to libexec, including hidden files
    libexec.install Dir["*", ".*"].reject { |f| f == "." || f == ".." }
    
    # Create Python virtual environment
    venv = libexec/"venv"
    system Formula["python@3.10"].bin/"python3.10", "-m", "venv", venv
    
    # Install Python requirements
    system venv/"bin/pip", "install", "--upgrade", "pip"
    system venv/"bin/pip", "install", "-r", libexec/"requirements.txt"
    
    # Create separate virtual environment for notebooks
    notebook_venv = libexec/"notebook-venv"
    system Formula["python@3.10"].bin/"python3.10", "-m", "venv", notebook_venv
    system notebook_venv/"bin/pip", "install", "--upgrade", "pip"
    system notebook_venv/"bin/pip", "install", "jupyterlab", "ipykernel", "pandas", "matplotlib"
    
    # Create MLX virtual environment
    mlx_venv = libexec/"mlx-venv" 
    system Formula["python@3.10"].bin/"python3.10", "-m", "venv", mlx_venv
    system mlx_venv/"bin/pip", "install", "--upgrade", "pip"
    
    # Install MLX packages from requirements file if it exists
    if File.exist?(libexec/"requirements-mlx.txt")
      system mlx_venv/"bin/pip", "install", "-r", libexec/"requirements-mlx.txt"
    else
      # Fallback to basic MLX packages
      system mlx_venv/"bin/pip", "install", "mlx", "mlx-lm", "kamiwaza-mlx"
    end
    
    # Store environment settings for first-boot.sh to use
    env_override_file = libexec/".homebrew_env_overrides"
    env_overrides = []
    
    # KAMIWAZA_LITE setting
    if ENV["HOMEBREW_KAMIWAZA_LITE"]
      env_overrides << "KAMIWAZA_LITE=#{lite_mode}"
      ohai "Kamiwaza installation mode: #{lite_mode == 'true' ? 'Lite' : 'Full'}"
    end
    
    # Telemetry settings
    env_overrides << "KAMIWAZA_ANALYTICS_URL=#{analytics_url}"
    
    # Bridge Homebrew telemetry preference to app's expected variable
    if telemetry_enabled
      env_overrides << "TELEMETRY_OPT_OUT_OVERRIDE=false"
    else
      env_overrides << "TELEMETRY_OPT_OUT_OVERRIDE=true"
    end
    
    # License key setting
    if license_key != "COMMUNITY-EDITION-ONLY"
      env_overrides << "KAMIWAZA_LICENSE_KEY=#{license_key}"
      ohai "License key provided and will be configured during installation"
    end
    
    # Write all overrides to file
    env_override_file.write(env_overrides.join("\n"))
    
    # User notification about telemetry
    if telemetry_enabled
      ohai "Telemetry is enabled. Thank you for helping improve Kamiwaza!"
    else
      opoo "Telemetry is disabled. To opt in, reinstall with:"
      opoo "  HOMEBREW_KAMIWAZA_TELEMETRY=true brew reinstall kamiwaza"
    end
    
    # Create var directories
    (var/"kamiwaza").mkpath
    (var/"kamiwaza/data").mkpath
    (var/"kamiwaza/models").mkpath
    (var/"log/kamiwaza").mkpath
    
    # Create additional directories that post-install.sh was creating
    (etc/"kamiwaza").mkpath
    (libexec/"licenses").mkpath
    (libexec/"public").mkpath
    (libexec/"scripts").mkpath
    
    # Handle license key if provided
    if license_key != "COMMUNITY-EDITION-ONLY"
      ohai "Saving license key to licenses directory"
      (libexec/"licenses/kamiwaza.lic").write(license_key)
      (libexec/"licenses/kamiwaza.lic").chmod(0600)
    end
    
    # Copy license server public key if it exists
    if (libexec/"kamiwaza_license_server_pub.pem").exist?
      FileUtils.cp(libexec/"kamiwaza_license_server_pub.pem", libexec/"licenses/kamiwaza_license_server_pub.pem")
    elsif (libexec/"install-scripting/deb/kamiwaza_license_server_pub.pem").exist?
      FileUtils.cp(libexec/"install-scripting/deb/kamiwaza_license_server_pub.pem", libexec/"licenses/kamiwaza_license_server_pub.pem")
    end
    
    # Install NVM and Node.js (moved from post-install.sh)
    ohai "Installing NVM and Node.js..."
    nvm_dir = "#{ENV["HOME"]}/.nvm"
    unless Dir.exist?(nvm_dir)
      # Install NVM using a single bash command
      system "bash", "-c", <<~EOS
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
        export NVM_DIR="#{ENV["HOME"]}/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
        nvm install 22
        nvm use 22
        nvm alias default 22
        npm install -g pm2
      EOS
      ohai "Node.js 22 and PM2 installed successfully"
    else
      ohai "NVM already installed, ensuring Node.js 22 is available"
      system "bash", "-c", <<~EOS
        export NVM_DIR="#{ENV["HOME"]}/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
        nvm use 22 || nvm install 22
      EOS
    end
    
    # Compile frontend (moved from post-install.sh)
    if (libexec/"frontend").exist?
      ohai "Compiling frontend (this may take 2-3 minutes)..."
      Dir.chdir(libexec/"frontend") do
        # Ensure we use the correct npm with Node.js 22
        system "bash", "-c", <<~EOS
          export NVM_DIR="#{ENV["HOME"]}/.nvm"
          [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
          nvm use 22
          rm -rf package-lock.json node_modules
          npm install --no-progress --silent
          npm run build --loglevel=error
        EOS
      end
      ohai "Frontend compiled successfully"
    else
      opoo "Frontend directory not found - skipping frontend compilation"
    end
    
    # Create wrapper script
    (bin/"kamiwaza").write <<~EOS
      #!/bin/bash
      export KAMIWAZA_ROOT="#{libexec}"
      export KAMIWAZA_VENV="#{venv}"
      export KAMIWAZA_LOG_DIR="#{var}/log/kamiwaza"
      export PATH="#{venv}/bin:$PATH"
      
      # Execute the startup script and replace references in output
      "#{libexec}/startup/kamiwazad.sh" "$@" 2>&1 | sed 's/kamiwazad\\.sh/kamiwaza/g'
    EOS
    
    chmod 0755, bin/"kamiwaza"
    
    # Install kamiwaza wheel into all virtual environments
    wheel_file = Dir["#{libexec}/kamiwaza-*.whl"].first
    if wheel_file
      ohai "Installing kamiwaza wheel into virtual environments..."
      
      # Install into main venv
      if (libexec/"venv").exist?
        system "#{libexec}/venv/bin/pip", "install", "--quiet", wheel_file
      end
      
      # Install into notebook-venv if it exists
      if (libexec/"notebook-venv").exist?
        system "#{libexec}/notebook-venv/bin/pip", "install", "--quiet", wheel_file
      end
      
      # Install into mlx-venv if it exists (Apple Silicon only)
      if (libexec/"mlx-venv").exist?
        system "#{libexec}/mlx-venv/bin/pip", "install", "--quiet", wheel_file
      end
    else
      opoo "Kamiwaza wheel not found - Python module may not be available"
    end
    
    # Create env.sh with KAMIWAZA_LLAMACPP_PATH if it doesn't exist
    (etc/"kamiwaza").mkpath
    unless File.exist?(etc/"kamiwaza/env.sh")
      ohai "Creating env.sh with Homebrew llama.cpp configuration..."
      env_content = File.read(libexec/"env.sh.example")
      
      # Add KAMIWAZA_LLAMACPP_PATH pointing to Homebrew's llama.cpp
      if Formula["llama.cpp"].opt_bin.exist?
        env_content += "\n# Homebrew llama.cpp location\n"
        env_content += "export KAMIWAZA_LLAMACPP_PATH=\"#{Formula["llama.cpp"].opt_bin}\"\n"
      end
      
      File.write(etc/"kamiwaza/env.sh", env_content)
    end
    
    # Run first-boot.sh to handle JWT keys, database setup, and env.sh creation
    ohai "Running first-boot setup (JWT keys, database initialization, env.sh creation)..."
    Dir.chdir(libexec) do
      first_boot_args = "--community"
      first_boot_args += lite_mode == "true" ? " --lite" : " --full"
      
      ohai "Running first-boot.sh with args: #{first_boot_args}"
      unless system "bash", "first-boot.sh", *first_boot_args.split
        opoo "first-boot.sh failed - database initialization may be incomplete"
        opoo "You may need to run: kamiwaza init-db"
      end
    end
    
    # Install post-install script to pkgshare
    # Look for post-install.sh in the libexec directory
    post_install_candidates = [
      "install-scripting/brew/resources/post-install.sh",
      "post-install.sh",
      "resources/post-install.sh"
    ]
    
    post_install_found = false
    post_install_candidates.each do |candidate|
      full_path = libexec/candidate
      if full_path.exist?
        pkgshare.install full_path => "post-install.sh"
        ohai "Installed post-install.sh from #{candidate}"
        post_install_found = true
        break
      end
    end
    
    unless post_install_found
      opoo "post-install.sh not found in package - post-installation tasks may not run"
    end
    
    # Install uninstall-cleanup script to pkgshare
    uninstall_cleanup_candidates = [
      "install-scripting/brew/resources/uninstall-cleanup.sh",
      "uninstall-cleanup.sh",
      "resources/uninstall-cleanup.sh"
    ]
    
    uninstall_cleanup_found = false
    uninstall_cleanup_candidates.each do |candidate|
      full_path = libexec/candidate
      if full_path.exist?
        pkgshare.install full_path => "uninstall-cleanup.sh"
        ohai "Installed uninstall-cleanup.sh from #{candidate}"
        uninstall_cleanup_found = true
        break
      end
    end
    
    unless uninstall_cleanup_found
      opoo "uninstall-cleanup.sh not found in package - uninstall cleanup may be incomplete"
    end
    
    # Create setup completion marker if installation succeeded
    unless setup_already_complete
      ohai "Creating setup completion marker"
      (libexec/".kamiwaza_setup_complete").write("Installation completed at: #{Time.now}\n")
    end
  end

  def post_install
    # Read environment variable for lite mode
    lite_mode = ENV["HOMEBREW_KAMIWAZA_LITE"] || "true"
    
    # Run post-install setup script
    # Note: setup.sh compiles frontend and llama.cpp which can take several minutes
    # The timeout is handled inside post-install.sh itself
    with_env({
      "KAMIWAZA_ROOT" => libexec.to_s,
      "KAMIWAZA_VENV" => "#{libexec}/venv",
      "KAMIWAZA_DATA_DIR" => "#{var}/kamiwaza/data",
      "KAMIWAZA_LOG_DIR" => "#{var}/log/kamiwaza",
      "HOMEBREW_PREFIX" => HOMEBREW_PREFIX.to_s,
      "KAMIWAZA_LITE" => lite_mode
    }) do
      system "bash", "-c", <<~EOS
        # Source and run the post-install script with required arguments
        cd "#{libexec}"
        if [ -f "#{pkgshare}/post-install.sh" ]; then
          bash "#{pkgshare}/post-install.sh" "#{libexec}" "#{etc}/kamiwaza" "#{var}/kamiwaza"
        else
          echo "Warning: post-install.sh not found at #{pkgshare}/post-install.sh"
        fi
      EOS
    end
    
    # Check if post-install completed successfully
    exit_status = $?.exitstatus
    if exit_status != 0
      opoo "Post-install setup completed with minor issues (exit code: #{exit_status})"
      opoo "This is usually related to shell profile configuration"
      ohai "Kamiwaza should still be functional. To retry setup:"
      ohai "  brew postinstall kamiwaza"
      opoo "Most compilation was completed during main installation"
    end
  end

  def caveats
    # Determine what was actually installed
    installation_mode = ENV["HOMEBREW_KAMIWAZA_LITE"] == "false" ? "Full" : "Lite"
    telemetry_status = ENV["HOMEBREW_KAMIWAZA_TELEMETRY"] == "false" ? "disabled" : "enabled"
    license_type = ENV["HOMEBREW_KAMIWAZA_LICENSE_KEY"] && 
                   ENV["HOMEBREW_KAMIWAZA_LICENSE_KEY"] != "COMMUNITY-EDITION-ONLY" ? 
                   "Enterprise" : "Community"
    
    <<~EOS
      #{Formatter.headline("License")}
      
      By using Kamiwaza, you agree to the Kamiwaza End User License Agreement.
      View the full license at: https://kamiwaza.ai/license
      
      #{Formatter.headline("Installation Summary")}
      
      Kamiwaza #{license_type} Edition (#{installation_mode} mode)
      Telemetry: #{telemetry_status}
      
      Web Interface: https://localhost
      API Documentation: http://localhost:7777/docs
      
      Default credentials:
        Username: admin
        Password: kamiwaza
      
      Logs: #{var}/log/kamiwaza/kamiwaza.log
      
      #{Formatter.headline("Getting Started")}
      
      To start Kamiwaza:
        kamiwaza start
      
      To check status:
        kamiwaza status
      
      To stop Kamiwaza:
        kamiwaza stop
      
      #{Formatter.headline("Before Uninstalling")}
      
      IMPORTANT: Before uninstalling Kamiwaza, you should:
      
      1. Stop the brew service (if enabled):
         brew services stop kamiwaza-ai/kamiwaza/kamiwaza
      
      2. Run the cleanup script to stop all services and clean up resources:
         bash #{HOMEBREW_PREFIX}/opt/kamiwaza/share/kamiwaza/uninstall-cleanup.sh
      
      This will stop all Kamiwaza processes, Docker containers, and clean up
      temporary files. Logs are saved to /tmp/kamiwaza-uninstall-*.log
      
      3. Then uninstall:
         brew uninstall kamiwaza
    EOS
  end

  test do
    # Test that the kamiwaza command exists and returns version
    assert_match version.to_s, shell_output("#{bin}/kamiwaza version 2>&1")
    
    # Test that Python virtual environment was created
    assert_predicate libexec/"venv/bin/python", :exist?
    
    # Test that .kamiwaza_install_community file exists (indicates community edition)
    assert_predicate libexec/".kamiwaza_install_community", :exist?
  end
end