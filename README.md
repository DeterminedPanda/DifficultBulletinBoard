# Difficult Bulletin Board - Addon for Turtle WoW

**Difficult Bulletin Board** is a World of Warcraft 1.12 addon inspired by the LFG Group Bulletin Board. It scans world chat and organizes messages into an easy-to-read UI, making it more convenient to find what you need.

## Features

- **Group Finder**: Easily locate groups for the content you want to do.
- **Profession Search**: Quickly find players offering or seeking crafting services.
- **Hardcore Messages**: Stay updated with hardcore-related events, such as deaths or level-ups.

### Group Finder

![screenshot](images/groups.png)

### Profession Search

![screenshot](images/professions.png)

### Hardcore Messages

![screenshot](images/hardcore.png)

## Installation

1. Download the addon by clicking the link below:
   - [Download Difficult Bulletin Board](https://github.com/DeterminedPanda/DifficultBulletinBoard/archive/refs/heads/master.zip)

2. Unzip the `DifficultBulletinBoard-master.zip` archive.

3. Rename the directory inside the zip from `DifficultBulletinBoard-master` to `DifficultBulletinBoard`.

4. Move the `DifficultBulletinBoard` folder to your World of Warcraft AddOns directory:
   - Example path: `C:\World of Warcraft Turtle\Interface\AddOns`

5. If you have WoW open, make sure to restart the game for the addon to load properly.

6. To verify the installation, type `/dbb` in the game chat. If the installation was successful, the addon will open.


## Usage

### Accessing the Bulletin Board

You can open the bulletin board interface by left-clicking on the DifficultBulletinBoard Minimap icon or by typing ```/dbb``` into your chat window.
The interface will show an ordered list of messages from the world chat.

### Editing and Managing Entries

To manage topics, right-click the minimap icon to open the options window and select which topics to follow by selecting or unselecting the corresponding checkbox.

## Troubleshooting

### No Messages Show Up?
If no messages appear on your bulletin board and no errors are displayed, make sure you are in the **world chat** by typing `/join world` in-game.

### Tags List Issues?
If your tags list seems incorrect or disorganized, try pressing the **Reset** button in the options window.  
It’s also a good idea to reset the tags after updating the addon, as I may improve or adjust the tags list in future updates.

## Contact

Have feature suggestions or need further assistance? Feel free to [create an issue](https://github.com/DeterminedPanda/DifficultBulletinBoard/issues) on this repository and I will help you as soon as possible.


## To-Do List:

- [x] Ensure that when a person already in the list sends a new message, their old entry is removed and they are moved to the top of the list.
- [x] Add a reset button to the options frame.
- [x] Expand options (e.g., placeholder number adjustments, etc.).
- [x] Implement left-click whisper, shift-left-click /who, and right-click /invite functionality for buttons
- [x] Implement tabs
- [x] Implement a tab for Hardcore messages
- [ ] Implement more customization options (e.g., classic WoW border styles, etc.).
