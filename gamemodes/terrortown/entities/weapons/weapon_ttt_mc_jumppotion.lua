AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Rocket Potion"
   SWEP.Slot               = 3

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

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
SWEP.ViewModel             = "models/minecraft_original/mc_jumppotion.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_jumppotion.mdl"
SWEP.WorldModelEnt         = nil

SWEP.CustomAttachment      = "ValveBiped.Bip01_R_Hand"
SWEP.CustomWorldVector     = Vector(5, -2.7, 0)
SWEP.CustomAngle           = Angle(180, 90, 0)
SWEP.CustomViewVector      = Vector(40, -15, -15)
SWEP.Kind                  = WEAPON_NADE

local HealSound1           = Sound("minecraft_original/glass1.wav")
local HealSound2           = Sound("minecraft_original/launch1.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")

local mc_jump_primary_use = CreateConVar("ttt_mc_jump_primary_use", "15", FCVAR_REPLICATED, "The amount of ammo use to when using on someone else")
local mc_jump_secondary_use = CreateConVar("ttt_mc_jump_secondary_use", "5", FCVAR_REPLICATED, "The amount of ammo use to when using on yourself")

if SERVER then
    local enabled = CreateConVar("ttt_mc_jump_enabled", "1", FCVAR_ARCHIVE)
    local max_ammo = CreateConVar("ttt_mc_jump_max_ammo", "100", FCVAR_ARCHIVE)

    hook.Add("PreRegisterSWEP", "McJump_PreRegisterSWEP", function(weap, class)
        if class == "weapon_ttt_mc_jumppotion" then
            local is_enabled = enabled:GetBool()
            weap.AutoSpawnable = is_enabled
            weap.Spawnable = is_enabled

            local max = max_ammo:GetInt()
            weap.Primary.ClipSize = max
            weap.Primary.ClipMax = max
            weap.Primary.DefaultClip = max
        end
    end)
end

function SWEP:Initialize()
    self:SetHoldType("slam")
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    if CLIENT then
        self:AddHUDHelp("Left-click to boost your target", "Right-click repeatedly to boost yourself", false)
    end
end

function SWEP:Equip()
    self:EmitSound(EquipSound)
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
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
        self:EmitSound(HealSound1)
        ent:EmitSound(HealSound2)
        ent:SetGroundEntity(nil)
        ent:SetVelocity(Vector(0,0,600))
        local primaryAmount = mc_jump_primary_use:GetInt()
        self:TakePrimaryAmmo(primaryAmount)
    else
        self:EmitSound(DenySound)
    end
    if self:Clip1() <= 0 then
        self:Remove()
        self:EmitSound(DestroySound)
    end
end

function SWEP:SecondaryAttack()
    local powner = self:GetOwner()
    self:EmitSound(HealSound2)
    powner:SetGroundEntity(nil)
    powner:SetVelocity(Vector(0,0,200))
    local secondaryAmount = mc_jump_secondary_use:GetInt()
    self:TakePrimaryAmmo(secondaryAmount)
    if self:Clip1() <= 0 then
        if SERVER then self:Remove() end
        self:EmitSound(DestroySound)
    end
end

function SWEP:OnRemove()
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

if CLIENT then
    function SWEP:DrawWorldModel()
        -- Make sure the model is valid
        if not self.WorldModelEnt or (self.WorldModelEnt == NULL) then
            self.WorldModelEnt = ClientsideModel(self.WorldModel)
            self.WorldModelEnt:SetNoDraw(true)
        end

        -- If it isn't, bail
        if not self.WorldModelEnt or (self.WorldModelEnt == NULL) then
            return
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