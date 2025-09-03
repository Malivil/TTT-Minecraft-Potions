AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Speed Potion"
   SWEP.Slot               = 3

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

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
SWEP.ViewModel             = "models/minecraft_original/mc_speedpotion.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_speedpotion.mdl"
SWEP.WorldModelEnt         = nil

SWEP.CustomAttachment      = "ValveBiped.Bip01_R_Hand"
SWEP.CustomWorldVector     = Vector(5, -2.7, 0)
SWEP.CustomAngle           = Angle(180, 90, 0)
SWEP.CustomViewVector      = Vector(40, -15, -15)
SWEP.Kind                  = WEAPON_NADE
SWEP.PotionEnabled         = false
SWEP.InitWalkSpeed         = nil
SWEP.InitRunSpeed          = nil
SWEP.PreviousOwner         = nil

local HealSound1           = Sound("minecraft_original/speed_end.wav")
local HealSound2           = Sound("minecraft_original/speed_start.wav")
local HealSound3           = Sound("minecraft_original/speed_attack.wav")
local HealSound4           = Sound("minecraft_original/glass1.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")

local mc_speed_walk_mult = CreateConVar("ttt_mc_speed_walk_mult", "3", FCVAR_REPLICATED, "The multiplier to use for the player's walk speed")
local mc_speed_run_mult = CreateConVar("ttt_mc_speed_run_mult", "5", FCVAR_REPLICATED, "The multiplier to use for the player's run speed")
local mc_speed_push_cost = CreateConVar("ttt_mc_speed_push_cost", "20", FCVAR_REPLICATED, "The amount of ammo to use when pushing a target")

if SERVER then
    local enabled = CreateConVar("ttt_mc_speed_enabled", "1", FCVAR_ARCHIVE)
    local max_ammo = CreateConVar("ttt_mc_speed_max_ammo", "100", FCVAR_ARCHIVE)

    hook.Add("PreRegisterSWEP", "McSpeed_PreRegisterSWEP", function(weap, class)
        if class == "weapon_ttt_mc_speedpotion" then
            local is_enabled = enabled:GetBool()
            weap.AutoSpawnable = is_enabled
            weap.Spawnable = is_enabled

            local max = max_ammo:GetInt()
            weap.MaxAmmo = max
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
        self:AddHUDHelp("Left-click to push your target", "Right-click to grant yourself a temporary speed boost", false)
    end
end

function SWEP:Equip(owner)
    self.PreviousOwner = owner
    self:EmitSound(EquipSound)
end

function SWEP:SpeedEnable()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.InitWalkSpeed = owner:GetWalkSpeed()
    self.InitRunSpeed = owner:GetRunSpeed()
    self:EmitSound(HealSound2)

    local walkMult = mc_speed_walk_mult:GetInt()
    owner:SetWalkSpeed(self.InitWalkSpeed * walkMult)
    local runMult = mc_speed_run_mult:GetInt()
    owner:SetRunSpeed(self.InitRunSpeed * runMult)
    timer.Create("use_ammo" .. self:EntIndex(), 0.1, 0, function()
        if self:Clip1() <= self.MaxAmmo then self:SetClip1(math.min(self:Clip1() - 1, self.MaxAmmo)) end
        if self:Clip1() <= 0 then
            self:SpeedDisable()
            if SERVER then self:Remove() end
            self:EmitSound(DestroySound)
        end
    end)
    self.PotionEnabled = true
end

function SWEP:SpeedDisable()
    -- Only play the sound if we're enabled, but run everything else
    -- so we're VERY SURE this disables
    if self.PotionEnabled then
        self:EmitSound(HealSound1)
    end

    local owner = self:GetOwner()
    if not IsValid(owner) then
        owner = self.PreviousOwner
    end

    if IsValid(owner) then
        if self.InitWalkSpeed then
            owner:SetWalkSpeed(self.InitWalkSpeed)
        end
        if self.InitRunSpeed then
            owner:SetRunSpeed(self.InitRunSpeed)
        end
    end

    timer.Remove("use_ammo" .. self:EntIndex())
    self.PotionEnabled = false
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if owner:IsPlayer() then
        owner:LagCompensation(true)
    end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 64,
        filter = owner
    })

    local ent = tr.Entity
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
        self:EmitSound(HealSound4)
        ent:EmitSound(HealSound3)
        ent:SetGroundEntity(nil)
        local pushvector = owner:GetAimVector() * 640
        pushvector.z = 100
        ent:SetVelocity(pushvector)
        local pushCost = mc_speed_push_cost:GetInt()
        self:TakePrimaryAmmo(pushCost)
    else
        self:EmitSound(DenySound)
    end
    if self:Clip1() <= 0 then
        self:Remove()
        self:EmitSound(DestroySound)
    end
end

function SWEP:SecondaryAttack()
    if self.PotionEnabled then
        self:SpeedDisable()
    else
        self:SpeedEnable()
    end
end

function SWEP:OnRemove()
    timer.Remove("use_ammo" .. self:EntIndex())
    self:SpeedDisable()

    if CLIENT then
        local owner = self:GetOwner()
        if not IsValid(owner) then
            owner = self.PreviousOwner
        end

        if IsValid(owner) and owner == LocalPlayer() and owner:Alive() then
            RunConsoleCommand("lastinv")
        end

        if IsValid(self.WorldModelEnt) then
            self.WorldModelEnt:Remove()
            self.WorldModelEnt = nil
        end
    end

    self.PreviousOwner = nil
end

function SWEP:Holster()
    return true
end

function SWEP:PreDrop()
    timer.Remove("use_ammo" .. self:EntIndex())
    self:SpeedDisable()
    self.BaseClass.PreDrop(self)
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