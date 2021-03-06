AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Invisibility Potion"
   SWEP.Slot               = 3

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

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

SWEP.UseHands              = false
SWEP.ViewModel             = "models/minecraft_original/mc_invispotion.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_invispotion.mdl"
SWEP.WorldModelEnt         = nil

SWEP.CustomAttachment      = "ValveBiped.Bip01_R_Hand"
SWEP.CustomWorldVector     = Vector(5, -2.7, 0)
SWEP.CustomAngle           = Angle(180, 90, 0)
SWEP.CustomViewVector      = Vector(40, -15, -15)
SWEP.Kind                  = WEAPON_NADE

local HealSound1           = Sound("minecraft_original/invisible_end.wav")
local HealSound2           = Sound("minecraft_original/invisible_start.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")
local Hidden               = false

function SWEP:Initialize()
    self:SetHoldType("slam")
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    if CLIENT then
        self:AddHUDHelp("Right-click to grant yourself temporary invisibility", false)
    end
end

function SWEP:Equip()
    self:EmitSound(EquipSound)
end

function SWEP:PlayerHide()
    self:GetOwner():SetColor(Color(255, 255, 255, 3))
    self:GetOwner():SetMaterial("sprites/heatwave")
    self:EmitSound(HealSound2)
    self:TakePrimaryAmmo(1)
    timer.Create("use_ammo" .. self:EntIndex(), 0.1, 0, function()
        if self:Clip1() <= self.MaxAmmo then self:SetClip1(math.min(self:Clip1() - 1, self.MaxAmmo)) end
        if self:Clip1() <= 0 then
            if SERVER then self:Remove() end
            self:EmitSound(DestroySound)
        end
    end)
    Hidden = true
end

function SWEP:PlayerUnhide()
    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:SetColor(Color(255, 255, 255, 255))
        owner:SetMaterial("models/glass")
    end

    self:EmitSound(HealSound1)
    timer.Stop("use_ammo" .. self:EntIndex())
    Hidden = false
end

function SWEP:PrimaryAttack()
    self:EmitSound(DenySound)
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
    return true
end

function SWEP:PreDrop()
    self.BaseClass.PreDrop(self)
    timer.Stop("use_ammo" .. self:EntIndex())
    if Hidden then self:PlayerUnhide() end
end

if CLIENT then
    function SWEP:DrawWorldModel()
        if not self.WorldModelEnt then
            self.WorldModelEnt = ClientsideModel(self.WorldModel)
            self.WorldModelEnt:SetNoDraw(true)
        end

        local owner = self:GetOwner()
        if IsValid(owner) then
            local boneid = owner:LookupBone(self.CustomAttachment)
            if not boneid or boneid <= 0 then return end

            local matrix = owner:GetBoneMatrix(boneid)
            if not matrix then return end

            local newPos, newAng = LocalToWorld(self.CustomWorldVector, self.CustomAngle, matrix:GetTranslation(), matrix:GetAngles())

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
        local newPos, _ = LocalToWorld(self.CustomViewVector, self.CustomAngle, eyePos, eyeAng)
        return newPos, eyeAng
    end
end