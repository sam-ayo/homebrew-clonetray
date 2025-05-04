class Clonetray < Formula
  include Language::Python::Virtualenv

  desc "Manages the clonetray background service"
  homepage "https://github.com/sam-ayo/automate-repo-cloning" # Optional: Replace with your repo URL
  url "https://github.com/sam-ayo/automate-repo-cloning/archive/refs/tags/v0.1.0.tar.gz" # Placeholder for local testing
  version "0.1.0" 
  sha256 "27359705daaf4700996b05c5f780ca3edbb5dee6a305eeee5f59e7c48479e665" # Add SHA256 checksum if distributing a tarball

  depends_on "python@3.11" 

  # Define Python package dependencies as resources
  resource "GitPython" do
    url "https://files.pythonhosted.org/packages/source/G/GitPython/gitpython-3.1.44.tar.gz"
    sha256 "c87e30b26253bf5418b01b0660f818967f3c503193838337fe5e573331249269"
  end

  resource "rumps" do
    # Assuming URL based on GitPython, SHA256 from Socket.dev pattern
    url "https://files.pythonhosted.org/packages/source/r/rumps/rumps-0.4.0.tar.gz"
    sha256 "17fb33c21b54b1e25db0d71d1d793dc19dc3c0b7d8c79dc6d833d0cffc8b1596" # Needs verification
  end

  def install
    # Create a virtual environment within libexec
    venv = virtualenv_create(libexec, "python3.11")

    # Install Python dependencies into the virtual environment
    venv.pip_install resources

    # Install the script into the virtual environment's site-packages
    # (or keep it in libexec if preferred, adjust plist accordingly)

    # If no setup.py, copy script manually into libexec (adjust path if needed)
    libexec.install "tray_clone.py" unless File.exist?("setup.py")

    # Install and modify the launchctl script
    bin.install "launchd.sh" => "clonetrayctl"
    inreplace bin/"clonetrayctl" do |s|
      # Remove plist creation/verification logic from the shell script
      s.gsub!(/^create_plist\(\).*?^\}/m, "")
      s.gsub!(/^# Check if plist exists.*?create_plist/m, "")
      s.gsub!(/^# Verify plist integrity.*?^fi$/m, "")

      # Update variables in the shell script to use the correct plist path and label
      s.gsub!(/PLIST_PATH=.*/, "PLIST_PATH=\"$HOME/Library/LaunchAgents/#{plist_name}.plist\"")
      s.gsub!(/PLIST_LABEL=.*/, "PLIST_LABEL=\"#{plist_name}\"")
      s.gsub!(/LABEL=\".*\"/, "LABEL=\"#{plist_name}\"")
    end

    # Generate the plist content
    plist_content = plist
    # Define the target plist filename
    plist_filename = "#{plist_name}.plist"
    # Write the plist file to a temporary location within the build directory
    (buildpath/plist_filename).write plist_content
    # Use prefix.install to copy the plist file to the formula's prefix 
    # and trigger Homebrew's automatic symlinking to ~/Library/LaunchAgents
    prefix.install plist_filename
    
    # Note: Homebrew automatically symlinks plist files installed via prefix.install
    # to ~/Library/LaunchAgents during installation.
  end

  def plist_name
    "com.user.clonetray"
  end

  # Update plist to use Python from the virtualenv
  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>#{plist_name}</string>

          <key>ProgramArguments</key>
          <array>
              <string>#{libexec}/bin/python</string>
              <string>#{libexec}/tray_clone.py</string>
          </array>

          <key>RunAtLoad</key>
          <true/>

          <key>KeepAlive</key>
          <true/>

          <key>StandardOutPath</key>
          <string>#{var}/log/clonetray.stdout.log</string>

          <key>StandardErrorPath</key>
          <string>#{var}/log/clonetray.stderr.log</string>

          <key>WorkingDirectory</key>
          <string>#{libexec}</string>

          # Remove EnvironmentVariables PATH modification if using venv's python
          # <key>EnvironmentVariables</key>
          # <dict>
          #     <key>PATH</key>
          #     <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:#{Formula["python@3.11"].opt_bin}</string>
          # </dict>
      </dict>
      </plist>
    EOS
  end

  service do
    # KeepAlive is set in the plist, so manage it there.
    # Let brew services use the plist defined by the #plist method.
  end

  test do
    # Update test if necessary, e.g., check for script in libexec
    assert_predicate libexec/"tray_clone.py", :exist?
    # The control script might not be necessary anymore if only used for plist creation
    # assert_predicate bin/"clonetrayctl", :exist?
    # assert_predicate bin/"clonetrayctl", :executable?
  end
end 