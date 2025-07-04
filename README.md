# Mac Trackpad Mapper

Maps a region of the trackpad to a region of the screen.

## How to Use (for Non-Developers)

Follow these steps to get the app running.

### 1. Download the App Files

You have two options. Pick one that's easiest for you.

**Option A: Download as a ZIP file**

1.  Go to the GitHub repository page for this project.
2.  Click the green `<> Code` button.
3.  Select `Download ZIP`.
4.  Unzip the downloaded file.

**Option B: Use Git (if you have it)**

Open your Terminal and run this command:

```bash
git clone https://github.com/jason-lewis/mac-trackpad-mapper.git
```

### 2. Install Developer Tools

The app needs Apple's Command Line Tools to be built. It's a one-time setup.

1.  Open the **Terminal** app (you can find it in `/Applications/Utilities`).
2.  Copy and paste this command into the Terminal and press Enter:

    ```bash
    xcode-select --install
    ```
3.  A window will pop up. Follow the instructions to install the tools. If it says the tools are already installed, you're all set.

### 3. Build the Application

Now, you'll compile the source code into a runnable app.

1.  Open the **Terminal** app.
2.  Navigate to the folder you downloaded and unzipped. For example, if it's in your Downloads folder, you would type:

    ```bash
    cd ~/Downloads/mac-trackpad-mapper-main
    ```
3.  Once you are in the correct directory, run this command:

    ```bash
    make release
    ```

### 4. Run the App

1.  After the `make release` command finishes, a new `build` folder will appear. Inside it, you will find **Trackpad Mapper.app**.
2.  You can double-click **Trackpad Mapper.app** to run it immediately.
3.  Alternatively, you can install it to your main Applications folder by running this command in the Terminal:
    ```bash
    make install
    ```
    After that, you can find and run "Trackpad Mapper" from your Applications folder like any other app.

### 5. Grant Permissions

The first time you run the app, your Mac will ask you to grant **Accessibility** permissions. You must do this for the app to work.

1.  Open **System Settings**.
2.  Go to **Privacy & Security** > **Accessibility**.
3.  Find **Trackpad Mapper** in the list and turn the switch on.

That's it! The app will now be running in your menu bar.