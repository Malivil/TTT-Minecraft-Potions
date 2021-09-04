AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Poison"
   SWEP.Slot               = 4

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.UseHands              = true
SWEP.HealAmount            = 100
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
SWEP.ViewModel             = "models/minecraft_original/mc_poison_h.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_poison_h.mdl"

SWEP.CustomPositon         = true
SWEP.CustomAttatchment     = "anim_attachment_rh"
SWEP.CustomVector          = Vector(-3,0,0)
SWEP.CustomAngle           = Angle(-23,0,0)

local HealSound1           = Sound("minecraft_original/drink1.wav")
local HealSound2           = Sound("minecraft_original/glass1.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:Equip()
    self:EmitSound(EquipSound)
end

function SWEP:DoPoison(ent, primary)
    local owner = self:GetOwner()
    local need = self.HealAmount
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
        need = math.min(ent:Health(), self:Clip1(), self.HealAmount)

        self:TakePrimaryAmmo(need)
        local spos = owner:GetShootPos()
        local sdest = spos + (owner:GetAimVector() * -10)
        local dmg = DamageInfo()
        dmg:SetDamage(need)
        dmg:SetAttacker(owner)
        dmg:SetInflictor(self.Weapon or self)
        dmg:SetDamageForce(owner:GetAimVector() * 3)
        dmg:SetDamagePosition(owner:GetPos())
        dmg:SetDamageType(DMG_POISON)

        ent:DispatchTraceAttack(dmg, spos + (owner:GetAimVector() * -1), sdest)
        ent:EmitSound(primary and HealSound2 or HealSound1)
        if self:Clip1() <= 0 then
            self:Remove()
            ent:EmitSound(DestroySound)
        end

        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

        if primary then
            self:SetNextPrimaryFire(CurTime() + self:SequenceDuration() + 0.5)
        else
            self:SetNextSecondaryFire(CurTime() + self:SequenceDuration() + 0.5)
        end
        owner:SetAnimation(PLAYER_ATTACK1)

        timer.Create("weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function()
            if IsValid(self) then self:SendWeaponAnim(ACT_VM_IDLE) end
        end)
    else
        owner:EmitSound(DenySound)
        if primary then
            self:SetNextPrimaryFire(CurTime() + 1)
        else
            self:SetNextSecondaryFire(CurTime() + 1)
        end
    end
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

    if self:GetOwner():IsPlayer() then
        self:GetOwner():LagCompensation(false)
    end

    local ent = tr.Entity
    self:DoPoison(ent, true)
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    self:DoPoison(self:GetOwner())
end

function SWEP:OnRemove()
    timer.Stop("weapon_idle" .. self:EntIndex())
end

function SWEP:Holster()
    timer.Stop("weapon_idle" .. self:EntIndex())
    return true
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