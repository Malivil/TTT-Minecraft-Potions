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

SWEP.CustomAttachment      = "ValveBiped.Bip01_R_Hand"
SWEP.CustomWorldVector     = Vector(5, -2.7, 0)
SWEP.CustomAngle           = Angle(180, 90, 0)
SWEP.CustomViewVector      = Vector(40, -15, -15)
SWEP.Kind                  = WEAPON_NADE

local HealSound1           = Sound("minecraft_original/drink1.wav")
local HealSound2           = Sound("minecraft_original/glass1.wav")
local DenySound            = Sound("minecraft_original/wood_click.wav")
local EquipSound           = Sound("minecraft_original/pop.wav")
local DestroySound         = Sound("minecraft_original/glass2.wav")

if SERVER then
    CreateConVar("ttt_mc_poison_alt_damage", "1", FCVAR_NONE, "Whether to use an alternate type of damage")
    CreateConVar("ttt_mc_poison_damage_tick_rate", "1", FCVAR_NONE, "How often (in seconds) to deal damage")
    CreateConVar("ttt_mc_poison_damage_per_tick", "1", FCVAR_NONE, "How much damage to deal per tick")
    local enabled = CreateConVar("ttt_mc_poison_enabled", "1", FCVAR_ARCHIVE)
    local max_ammo = CreateConVar("ttt_mc_poison_max_ammo", "100", FCVAR_ARCHIVE)

    hook.Add("PreRegisterSWEP", "McPoison_PreRegisterSWEP", function(weap, class)
        if class == "weapon_ttt_mc_poison" then
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

    if SERVER then
        SetGlobalInt("ttt_mc_poison_alt_damage", GetConVar("ttt_mc_poison_alt_damage"):GetInt())
        SetGlobalInt("ttt_mc_poison_damage_tick_rate", GetConVar("ttt_mc_poison_damage_tick_rate"):GetInt())
        SetGlobalInt("ttt_mc_poison_damage_per_tick", GetConVar("ttt_mc_poison_damage_per_tick"):GetInt())
    end
    if CLIENT then
        self:AddHUDHelp("Left-click to poison your target over time", "Right-click to poison yourself instantly", false)
    end
end

function SWEP:Equip()
    self:EmitSound(EquipSound)
end

if SERVER then
    local poisonTimers = {}
    local function StopPoison()
        for _, timerId in ipairs(poisonTimers) do
            timer.Remove(timerId)
        end
        table.Empty(poisonTimers)
    end
    hook.Add("TTTPrepareRound", "McPoisonResetTimers_PrepRound", StopPoison)
    hook.Add("TTTBeginRound", "McPoisonResetTimers_BeginRound", StopPoison)
    hook.Add("TTTEndRound", "McPoisonResetTimers_EndRound", StopPoison)

    function SWEP:DoPoison(ent, primary, action)
        local owner = self:GetOwner()
        local failure = true
        if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
            local need = math.min(ent:Health(), self:Clip1(), self.MaxAmmo)
            -- Don't actually do the effect if the callback fails
            if action(owner, ent, need) then
                failure = false
                self:TakePrimaryAmmo(need)

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
            end
        end

        if failure then
            owner:EmitSound(DenySound)
            if primary then
                self:SetNextPrimaryFire(CurTime() + 1)
            else
                self:SetNextSecondaryFire(CurTime() + 1)
            end
        end
    end

    function SWEP:PrimaryAttack()
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
            local timerId = "McPoisonTick_" .. self:EntIndex() .. "_" .. owner:EntIndex() .. "_" .. target:EntIndex()
            -- Don't let someone poison the same person twice with the same poison potion
            if timer.Exists(timerId) then
                return false
            end

            table.insert(poisonTimers, timerId)
            local alt_damage = GetGlobalInt("ttt_mc_poison_alt_damage", 1)
            local tick_rate = GetGlobalInt("ttt_mc_poison_damage_tick_rate", 1)
            local damage_per_tick = GetGlobalInt("ttt_mc_poison_damage_per_tick", 1)
            -- Tick however many times we need to do the total damage (e.g. 20 damage at 5 damage/tick should be 4 ticks)
            local ticks = math.Round(damage / damage_per_tick)
            timer.Create(timerId, tick_rate, ticks, function()
                -- If something happens to the target, stop trying to poison them
                if not IsValid(target) or not target:Alive() or target:IsSpec() then
                    timer.Remove(timerId)
                    return
                end

                local dmg = DamageInfo()
                dmg:SetDamage(damage_per_tick)
                dmg:SetAttacker(owner)
                if IsValid(self) then
                    dmg:SetInflictor(self)
                end
                dmg:SetDamagePosition(target:GetPos())
                if alt_damage then
                    dmg:SetDamageType(DMG_SLASH)
                else
                    dmg:SetDamageType(DMG_POISON)
                end

                target:TakeDamageInfo(dmg)
            end)
            return true
        end)
    end

    function SWEP:SecondaryAttack()
        self:DoPoison(self:GetOwner(), false, function(owner, target, damage)
            local hp = target:Health()
            local new_hp = hp - damage
            if new_hp <= 0 then
                target:Kill()
            else
                target:SetHealth(new_hp)
            end
            return true
        end)
    end
else
    function SWEP:PrimaryAttack() end
    function SWEP:SecondaryAttack() end
end

function SWEP:OnRemove()
    timer.Remove("weapon_idle" .. self:EntIndex())

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
    timer.Remove("weapon_idle" .. self:EntIndex())
    return true
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