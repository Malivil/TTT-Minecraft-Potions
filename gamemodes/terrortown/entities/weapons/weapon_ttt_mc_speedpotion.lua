AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Speed Potion"
   SWEP.Slot               = 4

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.UseHands              = true
SWEP.HealAmount            = 20
SWEP.MaxAmmo               = 100
SWEP.Primary.Delay         = 0.19
SWEP.Primary.Recoil        = 1.6
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"
SWEP.Primary.Damage        = -1
SWEP.Primary.Cone          = 0.018
SWEP.Primary.ClipSize      = 100
SWEP.Primary.ClipMax       = 100
SWEP.Primary.DefaultClip   = 100
SWEP.Primary.Sound         = Sound("Weapon_M4A1.Single")

SWEP.AutoSpawnable         = true
SWEP.Spawnable             = true

SWEP.UseHands              = true
SWEP.ViewModel             = "models/minecraft_original/mc_speedpotion.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_speedpotion.mdl"

SWEP.CustomPositon         = true
SWEP.CustomAttatchment     = "anim_attachment_rh"
SWEP.CustomVector          = Vector(-3,0,0)
SWEP.CustomAngle           = Angle(-23,0,0)

local HealSound1           = Sound("minecraft_original/speed_end.wav")
local HealSound2           = Sound("minecraft_original/speed_start.wav")
local HealSound3           = Sound("minecraft_original/speed_attack.wav")
local HealSound4           = Sound("minecraft_original/glass1.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")
local Hidden               = false
local InitWalkSpeed        = 1
local InitRunSpeed         = 1

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:Equip()
    self:EmitSound(EquipSound)
end

function SWEP:PlayerHide()
    InitWalkSpeed = self:GetOwner():GetWalkSpeed()
    InitRunSpeed = self:GetOwner():GetRunSpeed()
    self:EmitSound(HealSound2)
    self:GetOwner():SetWalkSpeed(InitWalkSpeed*3)
    self:GetOwner():SetRunSpeed(InitWalkSpeed*5)
    timer.Create("use_ammo" .. self:EntIndex(), 0.1, 0, function()
        if self:Clip1() <= self.MaxAmmo then self:SetClip1(math.min(self:Clip1() - 1, self.MaxAmmo)) end
        if self:Clip1() <= 0 then
            self:Remove()
            self:EmitSound(DestroySound)
        end
    end)
    Hidden = true
end

function SWEP:PlayerUnhide()
    self:EmitSound(HealSound1)
    self:GetOwner():SetWalkSpeed(InitWalkSpeed)
    self:GetOwner():SetRunSpeed(InitRunSpeed)
    timer.Stop("use_ammo" .. self:EntIndex())
    Hidden = false
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    if self:GetOwner():IsPlayer() then
        self:GetOwner():LagCompensation(true)
    end

    local tr = util.TraceLine({
        start = self:GetOwner():GetShootPos(),
        endpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * 64,
        filter = self:GetOwner()
    })

    local ent = tr.Entity
    if (IsValid(ent) and (ent:IsPlayer() or ent:IsNPC())) then
        self:EmitSound(HealSound4)
        ent:EmitSound(HealSound3)
        ent:SetGroundEntity(nil)
        local pushvector = self:GetOwner():GetAimVector() * 640
        pushvector.z = 100
        ent:SetVelocity(pushvector)
        self:TakePrimaryAmmo(20)
    else
        self:EmitSound(DenySound)
    end
    if self:Clip1() <= 0 then
        self:Remove()
        self:EmitSound(DestroySound)
    end
end

function SWEP:SecondaryAttack()
    if Hidden then
        self:PlayerUnhide()
    else
        self:PlayerHide()
    end
end

function SWEP:OnRemove()
    timer.Stop("use_ammo" .. self:EntIndex())
    if Hidden then self:PlayerUnhide() end
end

function SWEP:Holster()
    return true
end

function SWEP:PreDrop()
    timer.Stop("use_ammo" .. self:EntIndex())
    if Hidden then self:PlayerUnhide() end
end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay
end

--Position
function SWEP:DrawWorldModel()
    if not self.CustomPositon then
        self:DrawModel()
        return
    end

    if not self:GetOwner():IsValid() then
        self:DrawModel()
        return
    end

    local hand = 0
    if self:GetOwner():IsValid() and self:GetOwner():LookupAttachment(self.CustomAttatchment) then
        hand = self:GetOwner():LookupAttachment(self.CustomAttatchment)
    end

    if hand <= 0 then
        self:DrawModel()
        return
    end

    hand = self:GetOwner():GetAttachment(hand)
    local vector = hand.Ang:Right() * self.CustomVector.x + hand.Ang:Forward() * self.CustomVector.y + hand.Ang:Up() * self.CustomVector.z

    hand.Ang:RotateAroundAxis(hand.Ang:Right(), self.CustomAngle.x)
    hand.Ang:RotateAroundAxis(hand.Ang:Forward(), self.CustomAngle.y)
    hand.Ang:RotateAroundAxis(hand.Ang:Up(), self.CustomAngle.z)

    self:SetRenderOrigin(hand.Pos + vector)
    self:SetRenderAngles(hand.Ang)

    self:DrawModel()
end