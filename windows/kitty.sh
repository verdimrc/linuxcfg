# Disable Wayland as it doesn't understand Windows snap (win + arrow) shortcut.

# Integrated GPU
export GALLIUM_DRIVER=d3d12
export KITTY_DISABLE_WAYLAND=1

return
echo SHOULD NOT APPEAR...

# Discrete GPU
export GALLIUM_DRIVER=d3d12
export KITTY_DISABLE_WAYLAND=1
export MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"


###############################################################################
# Scratchpad
###############################################################################
# https://github.com/microsoft/WSL/issues/10547
export DISPLAY="$(grep nameserver /etc/resolv.conf | sed 's/nameserver //'):0"
#export MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
export MESA_D3D12_DEFAULT_ADAPTER_NAME="INTEL"
export LIBGL_ALWAYS_INDIRECT=0
export LIBGL_ALWAYS_SOFTWARE=0
# => glxgears still not working

#https://github.com/microsoft/WSL/issues/12412#issuecomment-2833534662
GALLIUM_DRIVER=d3d12 glxinfo -B
