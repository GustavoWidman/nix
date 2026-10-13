{ lib, pkgs, ... }:

{
  # Keep the passthrough guest on LTS while investigating the 7.2 amdgpu
  # page-table initialization crash (gmc_v9_0_get_vm_pde).
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # Test the pre-66a50fa initialization reset on the passed-through Cezanne
  # only. Keep the working LTS configuration as the normal boot entry.
  specialisation.gpu-kernel7.configuration = {
    system.nixos.tags = [ "gpu-kernel7" ];
    boot.kernelPackages = lib.mkOverride 40 pkgs.linuxPackages_latest;
    boot.kernelPatches = [
      {
        name = "cezanne-passthrough-init-reset";
        patch = pkgs.writeText "cezanne-passthrough-init-reset.patch" ''
          diff --git a/drivers/gpu/drm/amd/amdgpu/soc15.c b/drivers/gpu/drm/amd/amdgpu/soc15.c
          --- a/drivers/gpu/drm/amd/amdgpu/soc15.c
          +++ b/drivers/gpu/drm/amd/amdgpu/soc15.c
          @@ -826,6 +826,13 @@ static bool soc15_need_reset_on_init(struct amdgpu_device *adev)
           {
           	u32 sol_reg;
           
          +	/* VFIO guests cannot rely on a previous clean amdgpu unload.
          +	 * Restore initialization reset for passed-through Cezanne.
          +	 */
          +	if (adev->asic_type == CHIP_RENOIR && adev->pdev->device == 0x1638 &&
          +	    amdgpu_passthrough(adev))
          +		return true;
          +
           	if (amdgpu_gmc_need_reset_on_init(adev))
           		return true;
           	if (amdgpu_psp_tos_reload_needed(adev))
        '';
      }
    ];
  };

  # Cezanne passthrough needs the green_sardine firmware in the guest.
  hardware.firmware = [ pkgs.linux-firmware ];
  hardware.graphics.enable = true;

  users.users.r3dlust.extraGroups = [
    "video"
    "render"
  ];
}
