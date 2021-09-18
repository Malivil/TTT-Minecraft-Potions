AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Poison"
   SWEP.Slot               = 3

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

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

SWEP.UseHands              = false
SWEP.ViewModel             = "models/minecraft_original/mc_poison_h.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_poison_h.mdl"
SWEP.WorldModelEnt         = nil

SWEP.CustomAttatchment     = "ValveBiped.Bip01_R_Hand"
SWEP.CustomWorldVector     = Vector(5, -2.7, 0)
SWEP.CustomWorldAngle      = Angle(180, 90, 0)
SWEP.CustomViewVector      = Vector(40, -15, -15)
SWEP.Kind                  = WEAPON_NADE

local HealSound1           = Sound("minecraft_original/drink1.wav")
local HealSound2           = Sound("minecraft_original/glass1.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")

function SWEP:Initialize()
    self:SetHoldType("slam")
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    if CLIENT then
        self:AddHUDHelp("Left-click to poison your target over time", "Right-click to poison yourself instantly", false)
    end
end

function SWEP:Equip()
    self:EmitSound(EquipSound)
end

function SWEP:DoPoison(ent, primary, action)
    local owner = self:GetOwner()
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
        local need = math.min(ent:Health(), self:Clip1(), self.HealAmount)
        self:TakePrimaryAmmo(need)

        action(owner, ent, need)
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
    self:DoPoison(ent, true, function(owner, target, damage)
        timer.Create("McPoisonTicket_" .. self:EntIndex() .. "_" .. owner:EntIndex() .. "_" .. target:EntIndex(), 1, damage, function()
            if not IsValid(target) or not target:Alive() or target:IsSpec() then return end

            local dmg = DamageInfo()
            dmg:SetDamage(1)
            dmg:SetAttacker(owner)
            if IsValid(self) then
                dmg:SetInflictor(self)
            end
            dmg:SetDamagePosition(owner:GetPos())
            dmg:SetDamageType(DMG_POISON)

            target:TakeDamageInfo(dmg)
        end)
    end)
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    self:DoPoison(self:GetOwner(), false, function(owner, target, damage)
        local hp = target:Health()
        local new_hp = hp - damage
        if new_hp <= 0 then
            target:Kill()
        else
            target:SetHealth(new_hp)
        end
    end)
end

function SWEP:OnRemove()
    timer.Stop("weapon_idle" .. self:EntIndex())

    if CLIENT then
        if IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
            RunConsoleCommand("lastinv")
        end

        if IsValid(self.WorldModelEnt) then
            self.WorldModelEnt:Remove()
            self.WorldModelEnt = nil
        end
    end
end

function SWEP:Holster()
    timer.Stop("weapon_idle" .. self:EntIndex())
    return true
end

if CLIENT then
    function SWEP:DrawWorldModel()
        if not self.WorldModelEnt then
            self.WorldModelEnt = ClientsideModel(self.WorldModel)
            self.WorldModelEnt:SetSkin(1)
            self.WorldModelEnt:SetNoDraw(true)
        end

        local owner = self:GetOwner()
        if IsValid(owner) then
            local boneid = owner:LookupBone(self.CustomAttatchment)
            if boneid <= 0 then return end

            local matrix = owner:GetBoneMatrix(boneid)
            if not matrix then return end

            local newPos, newAng = LocalToWorld(self.CustomWorldVector, self.CustomWorldAngle, matrix:GetTranslation(), matrix:GetAngles())

            self.WorldModelEnt:SetPos(newPos)
            self.WorldModelEnt:SetAngles(newAng)

            self.WorldModelEnt:SetupBones()
        else
            self.WorldModelEnt:SetPos(self:GetPos())
            self.WorldModelEnt:SetAngles(self:GetAngles())
        end

        self.WorldModelEnt:DrawModel()
    end

    function SWEP:CalcViewModelView(vm, oldEyePos, oldEyeAng, eyePos, eyeAng)
        local newPos, _ = LocalToWorld(self.CustomViewVector, self.CustomWorldAngle, eyePos, eyeAng)
        return newPos, eyeAng
    end
end