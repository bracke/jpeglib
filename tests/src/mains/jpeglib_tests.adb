with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with Jpeglib_Testing.Suite;

--  AUnit's plain Test_Runner reports success however many assertions
--  failed, so a build server ticks a job green over a failing suite.
--  The outcome is carried in the exit status here instead.
procedure Jpeglib_Tests is
   use type AUnit.Status;

   function Run is new AUnit.Run.Test_Runner_With_Status (Jpeglib_Testing.Suite.All_Tests);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status   : AUnit.Status;
begin
   Status := Run (Reporter);

   if Status /= AUnit.Success then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Jpeglib_Tests;
