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

SWEP.UseHands = true
SWEP.HealAmount = 100
SWEP.MaxAmmo = 100
SWEP.Primary.Delay         = 0.19
SWEP.Primary.Recoil        = 1.6
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"
SWEP.Primary.Damage        = -1
SWEP.Primary.Cone          = 0.018
SWEP.Primary.ClipSize      = 100
SWEP.Primary.ClipMax       = 100
SWEP.Primary.DefaultClip   = 100
SWEP.Primary.Sound         = Sound( "Weapon_M4A1.Single" )

SWEP.AutoSpawnable         = true
SWEP.Spawnable             = true

SWEP.UseHands              = true
SWEP.ViewModel             = "models/minecraft_original/mc_poison_h.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_poison_h.mdl"

SWEP.CustomPositon = true
SWEP.CustomAttatchment = "anim_attachment_rh"
SWEP.CustomVector = Vector(-3,0,0)
SWEP.CustomAngle = Angle(-23,0,0)

local HealSound1 = Sound( "minecraft_original/drink1.wav" )
local HealSound2 = Sound( "minecraft_original/glass1.wav" )
local DenySound = Sound( "minecraft_original/wood_click.wav" )
local EquipSound = Sound( "minecraft_original/pop.wav" )
local DestroySound = Sound( "minecraft_original/glass2.wav" )

function SWEP:Initialize()

    self:SetHoldType( "slam" )

    if ( CLIENT ) then return end


end

function SWEP:Equip()

    self:EmitSound( EquipSound )
    
end

function SWEP:PrimaryAttack()

    if ( CLIENT ) then return end

    if ( self.Owner:IsPlayer() ) then
        self.Owner:LagCompensation( true )
    end

    local tr = util.TraceLine( {
        start = self.Owner:GetShootPos(),
        endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 64,
        filter = self.Owner
    } )

    if ( self.Owner:IsPlayer() ) then
        self.Owner:LagCompensation( false )
    end

    local ent = tr.Entity

    local need = self.HealAmount
    if ( IsValid( ent ) ) then need = math.min( ent:Health(), self.HealAmount, self:Clip1() ) end
    if ( IsValid( ent ) && ( ent:IsPlayer() or ent:IsNPC() )) then

        self:TakePrimaryAmmo( need )
        local hitEnt = tr.Entity
        local spos = self:GetOwner():GetShootPos()
        local sdest = spos + (self:GetOwner():GetAimVector() * 70)
        local dmg = DamageInfo()
            dmg:SetDamage(need)
            dmg:SetAttacker(self:GetOwner())
            dmg:SetInflictor(self.Weapon or self)
            dmg:SetDamageForce(self:GetOwner():GetAimVector() * 0)
            dmg:SetDamagePosition(self:GetOwner():GetPos())
            dmg:SetDamageType(DMG_POISON)

            hitEnt:DispatchTraceAttack(dmg, spos + (self:GetOwner():GetAimVector() * 3), sdest)
        ent:EmitSound( HealSound2 )
        if self:Clip1() <= 0 then self:Remove() ent:EmitSound( DestroySound ) end

        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

        self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.5 )
        self.Owner:SetAnimation( PLAYER_ATTACK1 )

        -- Even though the viewmodel has looping IDLE anim at all times, we need this to make fire animation work in multiplayer
        timer.Create( "weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function() if ( IsValid( self ) ) then self:SendWeaponAnim( ACT_VM_IDLE ) end end )

    else

        self.Owner:EmitSound( DenySound )
        self:SetNextPrimaryFire( CurTime() + 1 )

    end

end

function SWEP:SecondaryAttack()

    if ( CLIENT ) then return end

    local ent = self.Owner

    local need = self.HealAmount
    if ( IsValid( ent ) ) then need = math.min( ent:Health(), self.HealAmount ) end
    if ( IsValid( ent ) ) then need = math.min( self:Clip1(), self.HealAmount ) end
    if ( IsValid( ent ) ) then

        self:TakePrimaryAmmo( need )
        local hitEnt = self:GetOwner()
        local spos = self:GetOwner():GetShootPos()
        local sdest = spos + (self:GetOwner():GetAimVector() * -10)
        local dmg = DamageInfo()
            dmg:SetDamage(need)
            dmg:SetAttacker(self:GetOwner())
            dmg:SetInflictor(self.Weapon or self)
            dmg:SetDamageForce(self:GetOwner():GetAimVector() * 3)
            dmg:SetDamagePosition(self:GetOwner():GetPos())
            dmg:SetDamageType(DMG_POISON)
            
            hitEnt:DispatchTraceAttack(dmg, spos + (self:GetOwner():GetAimVector() * -1), sdest)
        ent:EmitSound( HealSound1 )
        if self:Clip1() <= 0 then self:Remove() ent:EmitSound( DestroySound ) end

        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

        self:SetNextSecondaryFire( CurTime() + self:SequenceDuration() + 0.5 )
        self.Owner:SetAnimation( PLAYER_ATTACK1 )

        timer.Create( "weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function() if ( IsValid( self ) ) then self:SendWeaponAnim( ACT_VM_IDLE ) end        end )
        
    else

        ent:EmitSound( DenySound )
        self:SetNextSecondaryFire( CurTime() + 1 )

    end

end

function SWEP:OnRemove()

    --timer.Stop( "medkit_ammo" .. self:EntIndex() )
    timer.Stop( "weapon_idle" .. self:EntIndex() )

end

function SWEP:Holster()

    timer.Stop( "weapon_idle" .. self:EntIndex() )

    return true

end

function SWEP:CustomAmmoDisplay()

    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay

end
--Position
function SWEP:DrawWorldModel( )
 
        if !self.CustomPositon then
    self:DrawModel()
    return end
 
    local hand, vector = nil, self.CustomVector
   
    if !self.Owner:IsValid() then
        self:DrawModel( )
    return end
   
    if self.Owner:IsValid() and self.Owner:LookupAttachment( self.CustomAttatchment ) then
        hand = self.Owner:LookupAttachment( self.CustomAttatchment )
    end
 
    if !hand then
        self:DrawModel( )
    return end
   
   
    hand = self.Owner:GetAttachment(hand)
    vector = hand.Ang:Right( )*self.CustomVector.x + hand.Ang:Forward( )*self.CustomVector.y + hand.Ang:Up( )*self.CustomVector.z
 
    hand.Ang:RotateAroundAxis( hand.Ang:Right( ), self.CustomAngle.x )
    hand.Ang:RotateAroundAxis( hand.Ang:Forward( ), self.CustomAngle.y )
    hand.Ang:RotateAroundAxis( hand.Ang:Up( ), self.CustomAngle.z )
 
    self:SetRenderOrigin( hand.Pos + vector )
    self:SetRenderAngles( hand.Ang )
   
    self:DrawModel( )
   
end