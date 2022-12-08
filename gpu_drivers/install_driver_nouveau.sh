#!/usr/bin/bash

install_driver_nouveau()
{
    # install Nouveau packages
    echo "Installing Nouveau driver packages..."
pacstrap -i /mnt mesa lib32-mesa xf86-video-nouveau << install_commands
$(echo)
$(echo)
y
y
install_commands

    echo "Finished installing Nouveau drivers."
}
