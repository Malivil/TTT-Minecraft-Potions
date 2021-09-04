AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "Immortality Potion"
   SWEP.Slot               = 4

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.UseHands = true
SWEP.HealAmount = 20
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
SWEP.ViewModel             = "models/minecraft_original/mc_immortpotion.mdl"
SWEP.WorldModel            = "models/minecraft_original/mc_immortpotion.mdl"

SWEP.CustomPositon = true
SWEP.CustomAttatchment = "anim_attachment_rh"
SWEP.CustomVector = Vector(-3,0,0)
SWEP.CustomAngle = Angle(-23,0,0)

local HealSound1 = Sound( "minecraft_original/goddisable.wav" )
local HealSound2 = Sound( "minecraft_original/godenable.wav" )
local DenySound = Sound( "minecraft_original/wood_click.wav" )
local EquipSound = Sound( "minecraft_original/pop.wav" )
local DestroySound = Sound( "minecraft_original/glass2.wav" )
local Hidden = false

function SWEP:Initialize()

    self:SetHoldType( "slam" )

    if ( CLIENT ) then return end


end

function SWEP:Equip()

    self:EmitSound( EquipSound )
    

    
end

function SWEP:PlayerHide()
    self.Owner:SetColor( Color(0, 0, 255, 255) )             
    self:EmitSound( HealSound2 )
    self.Owner:GodEnable()
    self:TakePrimaryAmmo(1)
        timer.Create( "use_ammo" .. self:EntIndex(), 0.1, 0, function()
    if ( self:Clip1() <= self.MaxAmmo ) then self:SetClip1( math.min( self:Clip1() - 1, self.MaxAmmo ) ) end
    if self:Clip1() <= 0 then self:Remove() self:EmitSound( DestroySound ) end
    end )
    Hidden = true
end

function SWEP:PlayerUnhide()
    self.Owner:SetColor( Color(255, 255, 255, 255) )     
    self:EmitSound( HealSound1 )
    self.Owner:GodDisable()
    timer.Stop( "use_ammo" .. self:EntIndex() )
    Hidden = false
end

function SWEP:PrimaryAttack()

    self:EmitSound( DenySound )

end

function SWEP:SecondaryAttack()

    if Hidden == true then self:PlayerUnhide() else self:PlayerHide() end

    end


function SWEP:OnRemove()

    timer.Stop( "use_ammo" .. self:EntIndex() )
    if Hidden == true then self:PlayerUnhide() end

end

function SWEP:Holster()


    return true

end

function SWEP:PreDrop()

    timer.Stop( "use_ammo" .. self:EntIndex() )
    if Hidden == true then self:PlayerUnhide() end
    
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