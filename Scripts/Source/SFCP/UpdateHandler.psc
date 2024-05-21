ScriptName SFCP:UpdateHandler extends Quest

;-- Properties --------------------------------------
GlobalVariable Property SFCP_Version_Major Auto Const
{ Major SFCP Version }
GlobalVariable Property SFCP_Version_Minor Auto Const
{ Minor SFCP Version }
GlobalVariable Property SFCP_Version_Patch Auto Const
{ Patch SFCP Version }
ConditionForm Property SFCP_CND_AllResearchCompleted Auto Const
{ Has the player completed all current research projects }
Quest Property MQ401 Auto
{ New Game Plus Standard Handler }
Quest Property MQ206A Auto
{ Missed Beyond Measure }

;-- Variables  --------------------------------------
string sCurrentVersion = ""
; What is the last saved version we have seen? 
bool b001UndiscoveredTemplesFix = false
; https://www.starfieldpatch.dev/issues/231
bool b001CoraCoeFix = false
; https://www.starfieldpatch.dev/issues/369
bool b001CoeEstateFix = false
; https://www.starfieldpatch.dev/issues/370
bool b005HadrianFactionFix = false
; https://www.starfieldpatch.dev/issues/669
bool b005ResearchTutorialFix = false
; https://www.starfieldpatch.dev/issues/725
bool b012CoraCoreNewFix = false
; https://www.starfieldpatch.dev/issues/924

;-- Functions ---------------------------------------

Event OnQuestInit()
    ; When the quest starts up for the very first time, we need to check for updates.
    Self.CheckForUpdates()

    ; Register for MQ401 hitting stage 450 or 455 so that we can start the Cora Core Crew Quest
    ; Inital fix: #369. Revised fix: #924
    ; Also used for fix #940
    Self.RegisterForRemoteEvent(MQ401 as ScriptObject, "OnStageSet")
    ; Fix for https://www.starfieldpatch.dev/issues/545
    Self.RegisterForRemoteEvent(MQ206A as ScriptObject, "OnStageSet")
EndEvent

Function CheckForUpdates()
    String runningVersion = SFCP_Version_Major.GetValue() as Int+"."+SFCP_Version_Minor.GetValue() as Int+"."+SFCP_Version_Patch.GetValue() as Int
    SFCPUtil.WriteLog("Patch initialised, version: "+runningVersion)
    if (sCurrentVersion == "" || sCurrentVersion != runningVersion)
        SFCPUtil.WriteLog("Updating Starfield Community Patch. Current version: "+runningVersion+". Last Version: "+sCurrentVersion)
        Self.ApplyMissingFixes(runningVersion)
    Else
        SFCPUtil.WriteLog("No updates required. Current version: "+runningVersion+". Last Version: "+sCurrentVersion)
    endIf
    ; Save the version string between game loads for comparison later.
    sCurrentVersion = runningVersion
EndFunction

Function ApplyMissingFixes(string sNewVersion)
    int major = SFCP_Version_Major.GetValue() as Int
    int minor = SFCP_Version_Minor.GetValue() as Int
    int patch = SFCP_Version_Patch.GetValue() as Int

    ; Get NG+ count as this will be reused. 
    int iTimesEnteredUnity = GetTimesEnteredUnity()

    ; Fix for https://www.starfieldpatch.dev/issues/231
    if (!b001UndiscoveredTemplesFix || (CurrentVersionGTE(0,0,1)))
        SFCPUtil.WriteLog("Recounting undiscovered temples")
        StarbornTempleQuestScript templeManager = Game.GetForm(0x00214707) as StarbornTempleQuestScript
        int iDifference = templeManager.RecountUndiscoveredLocations()
        if (iDifference != 0) 
            SFCPUtil.WriteLog("Fixed undiscovered temples. Count adjusted by "+iDifference)
        else
            SFCPUtil.WriteLog("Undiscovered temples are correct. Fix skipped.")
        endif
        b001UndiscoveredTemplesFix = True
    endif

    ; Fix for https://github.com/Starfield-Community-Patch/Starfield-Community-Patch/issues/369
    if (!b001CoraCoeFix || (CurrentVersionGTE(0,0,1)))
        Quest CREW_EliteCrewCoraCoe = Game.GetForm(0x00187BF1) as Quest
        ; (auiStageID == 450 || auiStageID == 455)
        if ((MQ401.GetStageDone(450) || MQ401.GetStageDone(455)) && iTimesEnteredUnity > 0 && !CREW_EliteCrewCoraCoe.IsRunning())
            SFCPUtil.WriteLog("Starting Cora Coe crew quest")
            CREW_EliteCrewCoraCoe.Start()
        else 
            SFCPUtil.WriteLog("Cora Coe crew quest does not need to be manually started. Skipping Fix.")
        endif
        b001CoraCoeFix = True
    endif

    ; Fix for https://github.com/Starfield-Community-Patch/Starfield-Community-Patch/issues/370
    if (!b001CoeEstateFix || (CurrentVersionGTE(0,0,1)))
        ObjectReference CoeEstateFrontDoorREF = Game.GetForm(0x000E69EC) as ObjectReference
        GlobalVariable MQ401_SkipMQ = Game.GetForm(0x0017E006) as GlobalVariable
        Quest COM_Quest_SamCoe_Commitment = Game.GetForm(0x000DF7AD) as Quest
        ; Check if the player has entered Unity, skipped the main quest, and COM_Quest_SamCoe_Commitment has already started
        if (iTimesEnteredUnity > 0 && CoeEstateFrontDoorREF.IsLocked() && MQ401_SkipMQ.GetValue() as Int == 1 && COM_Quest_SamCoe_Commitment.IsRunning())
            SFCPUtil.WriteLog("Unlocking Coe Estate doors")
            CoeEstateFrontDoorREF.Lock(False, True, True)
        else
            SFCPUtil.WriteLog("Coe Estate doors do not require unlocking.")
        endif
        b001CoeEstateFix = True
    endif

    ; Fix for https://www.starfieldpatch.dev/issues/669
    if (!b005HadrianFactionFix || (CurrentVersionGTE(0,0,5)))
        SFCPUtil.WriteLog("Fixing Hadrian's faction assignments")
        Actor Crew_Elite_Hadrian = Game.GetFormFromFile(0x002B17C4, "Starfield.esm") as Actor
        Faction ConstellationFaction  = Game.GetFormFromFile(0x000191DC, "Starfield.esm") as Faction
        Faction CrimeFactionUC = Game.GetFormFromFile(0x0005BD93, "Starfield.esm") as Faction
        Crew_Elite_Hadrian.RemoveFromfaction(ConstellationFaction)
        Crew_Elite_Hadrian.AddToFaction(CrimeFactionUC)
        b005HadrianFactionFix = true
    endif

    ; Fix for https://www.starfieldpatch.dev/issues/725
    if (!b005ResearchTutorialFix || (CurrentVersionGTE(0,0,5)))
        Quest MQ_TutorialQuest_Misc06 = Game.GetForm(0x0000118F) as Quest
        if (MQ_TutorialQuest_Misc06.IsObjectiveDisplayed(10) && SFCP_CND_AllResearchCompleted.IsTrue(NONE, NONE))
            SFCPUtil.WriteLog("Shutting down research tutorial quest")
            MQ_TutorialQuest_Misc06.SetStage(100)
        endif
        b005ResearchTutorialFix = true
    endif

    ; Updated fix for https://www.starfieldpatch.dev/issues/924
    if (!b012CoraCoreNewFix || (CurrentVersionGTE(0, 1, 3)))
        SFCPUtil.WriteLog("Registered OnStageSet for MQ401 to apply Cora Coe Crew Fix")
        Self.RegisterForRemoteEvent(MQ401 as ScriptObject, "OnStageSet")
        b012CoraCoreNewFix = true
    endif

EndFunction

int Function GetTimesEnteredUnity()
    Actor player = Game.GetPlayer()
    ActorValue PlayerUnityTimesEntered = Game.GetForm(0x00219529) as ActorValue
    return player.GetValue(PlayerUnityTimesEntered) as Int
EndFunction

; The current version is greater than or equal to the fix version
bool Function CurrentVersionGTE(int newMajor, int newMinor, int newPatch)
    int major = SFCP_Version_Major.GetValue() as Int
    int minor = SFCP_Version_Minor.GetValue() as Int
    int patch = SFCP_Version_Patch.GetValue() as Int
    
    if (major >= newMajor) ;e.g. 2.0.0 > 1.0.0
        return true
    elseif (major == newMajor && minor >= newMinor) ; e.g. 1.1.0 > 1.0.1
        return true
    elseif (major == newMajor && minor == newMinor && patch >= newPatch) ; e.g. 0.0.2 > 0.0.1
        return true
    else
        return false
    endif

EndFunction

Event Quest.OnStageSet(Quest akSender, Int auiStageID, Int auiItemID)
    if (akSender == MQ401 && (auiStageID == 450 || auiStageID == 455))
        Quest CREW_EliteCrewCoraCoe = Game.GetForm(0x00187BF1) as Quest
        if (!CREW_EliteCrewCoraCoe.IsRunning() && GetTimesEnteredUnity() > 0)                
            SFCPUtil.WriteLog("Starting Cora Coe crew quest")
            CREW_EliteCrewCoraCoe.Start()
        else
            SFCPUtil.WriteLog("Cora Coe crew quest is already running. Fix skipped.")
        endif
    endif

    ; Fix for https://www.starfieldpatch.dev/issues/940
    ; Removes all companion perks when starting NG+. 
    ; If you had an active companion when entering the Untiy these perks are not removed.
    ; This can cause player dialogue options to be available when they should not be.
    if (akSender == MQ401 && auiStageID == 10)
        Perk CompanionCheckAndrejaPerk = Game.GetForm(0x001C5150) as Perk
        Perk CompanionCheckBarrettPerk = Game.GetForm(0x001C514E) as Perk
        Perk CompanionCheckSamCoePerk = Game.GetForm(0x0001C514D) as Perk
        Perk CompanionCheckSarahMorganPerk = Game.GetForm(0x001C514C) as Perk
        Actor PlayerRef = Game.GetPlayer()
        If PlayerRef.HasPerk(CompanionCheckAndrejaPerk)
            PlayerRef.RemovePerk(CompanionCheckAndrejaPerk)
        EndIf
        If PlayerRef.HasPerk(CompanionCheckBarrettPerk)
            PlayerRef.RemovePerk(CompanionCheckBarrettPerk)
        EndIf
        If PlayerRef.HasPerk(CompanionCheckSamCoePerk)
            PlayerRef.RemovePerk(CompanionCheckSamCoePerk)
        EndIf
        If PlayerRef.HasPerk(CompanionCheckSarahMorganPerk)
            PlayerRef.RemovePerk(CompanionCheckSarahMorganPerk)
        EndIf
    endif

    ; Fix for https://www.starfieldpatch.dev/issues/545
    ; Shuts down commitment quest for the dead companion if it is still running. This keeps the dead companion from being set as the active companion in stage 2000 of MQ206A.
    if (akSender == MQ206A && auiStageID == 1000)
        Quest COM_Quest_Andreja_Commitment = Game.GetForm(0x000B8633) as Quest
        Quest COM_Quest_Barrett_Commitment = Game.GetForm(0x001C7185) as Quest
        Quest COM_Quest_SamCoe_Commitment = Game.GetForm(0x000DF7AD) as Quest
        Quest COM_Quest_SarahMorgan_Commitment = Game.GetForm(0x0027B667) as Quest
        Quest MQ00 = Game.GetForm(0x00005790) as Quest
        Actor DeadCompanionREF = (MQ00.GetAlias(4) as ReferenceAlias).getActorRef()
        Actor AndrejaREF = (MQ206A.GetAlias(7) as ReferenceAlias).getActorRef()
        Actor BarrettREF = (MQ206A.GetAlias(6) as ReferenceAlias).getActorRef()
        Actor SamCoeREF = (MQ206A.GetAlias(4) as ReferenceAlias).getActorRef()
        Actor SarahMorganREF = (MQ206A.GetAlias(5) as ReferenceAlias).getActorRef()
        if (DeadCompanionREF == AndrejaREF && COM_Quest_Andreja_Commitment.IsRunning())
           COM_Quest_Andreja_Commitment.Stop()
        elseif (DeadCompanionREF == BarrettREF && COM_Quest_Barrett_Commitment.IsRunning())
           COM_Quest_Barrett_Commitment.Stop()
        elseif (DeadCompanionREF == SamCoeREF && COM_Quest_SamCoe_Commitment.IsRunning())
           COM_Quest_SamCoe_Commitment.Stop()
        elseif (DeadCompanionREF == SarahMorganREF && COM_Quest_SarahMorgan_Commitment.IsRunning())
           COM_Quest_SarahMorgan_Commitment.Stop()
        endif
    endif
EndEvent
