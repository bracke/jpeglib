with Jpeglib.Errors;

package body Jpeglib.Internal.Progressive is
   function Invalid
     (Component : Component_Index := Component_Index'First;
      Coefficient : Coefficient_Index := Coefficient_Index'First;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Scan_Invalid_Definition,
              (Frame_Component => Component,
               Coefficient => Coefficient,
               Detail => Detail,
               others => <>)));
   end Invalid;

   procedure Reset (State : out Scan_State) is
   begin
      State := (Seen => [others => [others => False]], Last_Low => [others => [others => 0]]);
   end Reset;

   function Accept_Coefficient
     (State : in out Scan_State;
      Component : Component_Index;
      Coefficient : Coefficient_Index;
      Ah : Successive_Approximation_Value;
      Al : Successive_Approximation_Value) return Results.Result
   is
   begin
      if Ah = 0 then
         if State.Seen (Component, Coefficient) then
            return Invalid (Component, Coefficient, Long_Long_Integer (Al));
         end if;
      elsif not State.Seen (Component, Coefficient)
        or else State.Last_Low (Component, Coefficient) /= Ah
      then
         return Invalid (Component, Coefficient, Long_Long_Integer (Ah));
      end if;

      State.Seen (Component, Coefficient) := True;
      State.Last_Low (Component, Coefficient) := Al;
      return Results.Success;
   end Accept_Coefficient;

   function Accept_Scan
     (State : in out Scan_State;
      Frame : Frames.Frame;
      Scan : Scans.Scan) return Results.Result
   is
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         return Frames.Status (Frame);
      elsif Frames.Mode (Frame) not in Progressive_DCT | Differential_Progressive_DCT then
         return Invalid;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         return Scans.Status (Scan);
      end if;

      for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
         Scan_Component := Scans.Component (Scan, Scan_Index);

         for Coefficient in Scans.Spectral_Start (Scan) .. Scans.Spectral_End (Scan) loop
            Outcome :=
              Accept_Coefficient
                (State,
                 Scan_Component.Frame_Component,
                 Coefficient_Index (Coefficient),
                 Scans.Successive_High (Scan),
                 Scans.Successive_Low (Scan));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Accept_Scan;

   function Coefficient_Seen
     (State : Scan_State;
      Component : Component_Index;
      Coefficient : Coefficient_Index) return Boolean
   is
   begin
      return State.Seen (Component, Coefficient);
   end Coefficient_Seen;
end Jpeglib.Internal.Progressive;
